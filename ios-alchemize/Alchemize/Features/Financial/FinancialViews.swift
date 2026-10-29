import SwiftUI
import SwiftData

private let incomeCategories = ["salary", "freelance", "business", "investment", "bonus", "other"]
private let expenseCategories = ["bills", "business", "personal", "food", "transport", "entertainment", "shopping", "health", "education", "other"]
private let financeCard = Color(red: 15/255, green: 10/255, blue: 30/255).opacity(0.75)

private struct FinanceCard: ViewModifier {
    var glow: Color = AZ.purple
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(financeCard, in: .rect(cornerRadius: 22, style: .continuous))
            .background(.ultraThinMaterial.opacity(0.5), in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(glow.opacity(0.25)))
            .shadow(color: glow.opacity(0.15), radius: 16)
    }
}

extension FinanceEntry {
    var net: Double { netAmount > 0 ? netAmount : amount }
}

struct FinancialView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FinanceEntry.date, order: .reverse) private var entries: [FinanceEntry]
    @State private var period = "monthly"
    @State private var addKind: AddKind?
    @State private var incomeMonth = Date()
    @State private var expenseMonth = Date()
    @State private var incomeDay: Date?
    @State private var expenseDay: Date?
    @State private var pendingDelete: FinanceEntry?

    struct AddKind: Identifiable { let kind: String; var id: String { kind } }

    private var range: (start: Date, end: Date, label: String) {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case "quarterly":
            let m = cal.component(.month, from: now)
            let qStartMonth = ((m - 1) / 3) * 3 + 1
            var c = cal.dateComponents([.year], from: now); c.month = qStartMonth; c.day = 1
            let start = cal.date(from: c) ?? now
            let end = cal.date(byAdding: .month, value: 3, to: start) ?? now
            return (start, end, "Q\((m - 1) / 3 + 1) \(cal.component(.year, from: now))")
        case "yearly":
            let start = cal.dateInterval(of: .year, for: now)?.start ?? now
            return (start, cal.date(byAdding: .year, value: 1, to: start) ?? now, "\(cal.component(.year, from: now))")
        default:
            let start = cal.dateInterval(of: .month, for: now)?.start ?? now
            return (start, cal.date(byAdding: .month, value: 1, to: start) ?? now, now.formatted(.dateTime.month(.wide).year()))
        }
    }

    private var inPeriod: [FinanceEntry] { entries.filter { $0.date >= range.start && $0.date < range.end } }
    private var gross: Double { inPeriod.filter { $0.kind == "income" }.reduce(0) { $0 + $1.amount } }
    private var net: Double { inPeriod.filter { $0.kind == "income" }.reduce(0) { $0 + $1.net } }
    private var expenses: Double { inPeriod.filter { $0.kind == "expense" }.reduce(0) { $0 + $1.amount } }
    private var leftOver: Double { net - expenses }

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: Color(red: 5/255, green: 2/255, blue: 17/255).opacity(0.65))
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        ForEach(["monthly", "quarterly", "yearly"], id: \.self) { p in
                            Button {
                                Haptics.select()
                                withAnimation(.snappy) { period = p }
                            } label: {
                                Text(p.capitalized)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(period == p ? .white : AZ.textSecondary)
                                    .frame(maxWidth: .infinity).frame(height: 38)
                                    .background(period == p ? AZ.purple : .clear, in: .rect(cornerRadius: 12))
                            }
                            .buttonStyle(.squish(0.95))
                        }
                    }
                    .padding(4)
                    .background(financeCard, in: .rect(cornerRadius: 16))

                    summary

                    calendarCard(title: "Income Calendar", icon: "chart.line.uptrend.xyaxis", tint: AZ.emerald, kind: "income", month: $incomeMonth, day: $incomeDay)
                    calendarCard(title: "Expense Calendar", icon: "chart.line.downtrend.xyaxis", tint: AZ.red, kind: "expense", month: $expenseMonth, day: $expenseDay)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Recent Transactions", icon: "receipt", tint: AZ.violetLight)
                        if inPeriod.isEmpty {
                            Text("No transactions for this period").font(.subheadline).foregroundStyle(AZ.textSecondary)
                        } else {
                            ForEach(inPeriod.prefix(15)) { e in transactionRow(e) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(FinanceCard())

                    NavigationLink { FinanceNotesView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "note.text").foregroundStyle(AZ.violetLight)
                                .frame(width: 40, height: 40).background(AZ.violetLight.opacity(0.15), in: .rect(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Financial Notes").font(.headline).foregroundStyle(.white)
                                Text("Logins, debt, savings & notepad").font(.caption).foregroundStyle(AZ.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                        }
                        .modifier(FinanceCard())
                    }
                    .buttonStyle(.squish(0.98))
                }
                .padding(20)
                .padding(.bottom, 30)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
        }
        .cosmicNavigation("Financial Tracker")
        .sheet(item: $addKind) { FinanceEntryEditor(kind: $0.kind) }
        .alert("Delete \(pendingDelete?.kind == "income" ? "Income" : "Expense")", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let e = pendingDelete { withAnimation { context.delete(e) }; Haptics.warning() }
            }
        } message: { Text("Are you sure?") }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(range.label) Summary").font(.title3.bold()).foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                stat("Gross Income", gross, AZ.emerald)
                stat("Net Income", net, AZ.emerald)
                stat("Total Expenses", expenses, AZ.red)
                stat("Money Left Over", leftOver, leftOver >= 0 ? AZ.emerald : AZ.red, bold: true)
            }
            HStack(spacing: 12) {
                addButton("Income", AZ.emerald) { addKind = .init(kind: "income") }
                addButton("Expense", AZ.red) { addKind = .init(kind: "expense") }
            }
        }
        .modifier(FinanceCard(glow: AZ.purple))
    }

    private func stat(_ label: String, _ value: Double, _ tint: Color, bold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(AZ.textSecondary)
            Text(Fmt.money(value))
                .font(.system(size: bold ? 20 : 18, weight: bold ? .heavy : .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: value)
    }

    private func addButton(_ title: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.medium(); action() } label: {
            Label(title, systemImage: "plus")
                .font(.headline).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(tint.gradient, in: .rect(cornerRadius: 14))
                .shadow(color: tint.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.squish)
    }

    private func calendarCard(title: String, icon: String, tint: Color, kind: String, month: Binding<Date>, day: Binding<Date?>) -> some View {
        let list = entries.filter { $0.kind == kind }
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: title, icon: icon, tint: tint)
            MonthCalendarView(month: month, selected: day.wrappedValue, accent: tint,
                              marked: { d in list.contains { Calendar.current.isDate($0.date, inSameDayAs: d) } }) { d in
                withAnimation(.snappy) {
                    day.wrappedValue = (day.wrappedValue.map { Calendar.current.isDate($0, inSameDayAs: d) } ?? false) ? nil : d
                }
            }
            if let d = day.wrappedValue {
                let items = list.filter { Calendar.current.isDate($0.date, inSameDayAs: d) }
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(kind == "income" ? "Income" : "Expenses") on \(d.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    if items.isEmpty {
                        Text(kind == "income" ? "No income on this day" : "No expenses on this day")
                            .font(.caption).foregroundStyle(AZ.textSecondary)
                    }
                    ForEach(items) { transactionRow($0) }
                }
                .padding(12)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .modifier(FinanceCard(glow: tint))
    }

    private func transactionRow(_ e: FinanceEntry) -> some View {
        let income = e.kind == "income"
        return HStack(spacing: 12) {
            Image(systemName: income ? "arrow.down.left" : "arrow.up.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(income ? AZ.emerald : AZ.red)
                .frame(width: 32, height: 32)
                .background((income ? AZ.emerald : AZ.red).opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title.isEmpty ? e.category.capitalized : e.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("\(e.category.capitalized) · \(e.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption).foregroundStyle(AZ.textSecondary)
            }
            Spacer()
            Text((income ? "+" : "−") + Fmt.money(e.amount))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(income ? AZ.emerald : AZ.red)
            Button { pendingDelete = e } label: {
                Image(systemName: "trash").font(.footnote).foregroundStyle(AZ.red.opacity(0.85))
            }
            .buttonStyle(.squish(0.8))
        }
    }
}

struct FinanceEntryEditor: View {
    let kind: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amount = ""
    @State private var netAmount = ""
    @State private var category = "other"
    @State private var date = Date()
    @State private var notes = ""

    private var income: Bool { kind == "income" }
    private var value: Double? { Double(amount.replacingOccurrences(of: ",", with: ".")) }
    private var canSave: Bool { (value ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            SheetCanvas {
                FieldLabel(text: income ? "Source" : "Expense Name")
                TextField(income ? "e.g. Salary, Freelance gig" : "e.g. Rent, Groceries", text: $title).cosmicField()
                FieldLabel(text: income ? "Gross Amount ($)" : "Amount ($)")
                TextField("0.00", text: $amount).keyboardType(.decimalPad).font(.title2.bold()).cosmicField()
                if income {
                    FieldLabel(text: "Net Amount ($, optional)")
                    TextField("Take-home after taxes", text: $netAmount).keyboardType(.decimalPad).cosmicField()
                }
                FieldLabel(text: "Category")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(income ? incomeCategories : expenseCategories, id: \.self) { c in
                        Chip(title: c.capitalized, isSelected: category == c, tint: income ? AZ.emerald : AZ.red) { category = c }
                    }
                }
                FieldLabel(text: "Date")
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .foregroundStyle(.white)
                    .tint(income ? AZ.emerald : AZ.red)
                    .cosmicField()
                FieldLabel(text: "Note (optional)")
                TextField("Additional details...", text: $notes, axis: .vertical).lineLimit(2...4).cosmicField()
                GradientButton(title: income ? "Add Income" : "Add Expense", icon: "plus",
                               gradient: LinearGradient(colors: income ? [AZ.emerald, Color(hex: 0x059669)] : [AZ.red, Color(hex: 0xDC2626)], startPoint: .leading, endPoint: .trailing)) { save() }
                    .disabled(!canSave).opacity(canSave ? 1 : 0.5)
            }
            .navigationTitle(income ? "Add Income" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save) }
        }
        .presentationBackground(AZ.night)
    }

    private func save() {
        guard let v = value, v > 0 else { return }
        let n = Double(netAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
        context.insert(FinanceEntry(kind: kind, title: title.trimmingCharacters(in: .whitespaces), amount: v, netAmount: income ? n : 0,
                                    category: category, date: date, notes: notes))
        Haptics.success()
        dismiss()
    }
}

struct FinanceNotesView: View {
    @Environment(\.modelContext) private var context
    @State private var notes: FinanceNotes?

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: Color(red: 5/255, green: 2/255, blue: 17/255).opacity(0.75))
            if let notes {
                FinanceNotesForm(notes: notes)
            }
        }
        .cosmicNavigation("Financial Notes")
        .onAppear { if notes == nil { notes = context.singleton { FinanceNotes() } } }
    }
}

private struct FinanceNotesForm: View {
    @Bindable var notes: FinanceNotes

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                section("Important Logins", icon: "lock.fill", tint: AZ.violetLight) {
                    TextField("Bank logins, investment accounts, credit card portals...", text: $notes.loginInfo, axis: .vertical)
                        .lineLimit(3...8).cosmicField()
                }
                section("Debt", icon: "creditcard.fill", tint: AZ.red) {
                    money("Total Debt Amount", $notes.debtAmount, AZ.red)
                    FieldLabel(text: "Debt Notes")
                    TextField("Credit cards, student loans, car payments, mortgage details...", text: $notes.debtNotes, axis: .vertical)
                        .lineLimit(3...8).cosmicField()
                }
                section("Savings", icon: "banknote.fill", tint: AZ.emerald) {
                    money("Savings Amount", $notes.savingsAmount, AZ.emerald)
                    money("Emergency Fund", $notes.emergencyFund, AZ.emerald)
                    FieldLabel(text: "Savings Notes")
                    TextField("Savings goals, account details, investment notes...", text: $notes.savingsNotes, axis: .vertical)
                        .lineLimit(3...8).cosmicField()
                }
                section("Notepad", icon: "pencil.and.list.clipboard", tint: AZ.amber) {
                    TextField("Jot down financial thoughts, reminders, goals...", text: $notes.notepad, axis: .vertical)
                        .lineLimit(6...20).cosmicField()
                    Text("Saves automatically").font(.caption).foregroundStyle(AZ.textTertiary)
                }
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: notes.notepad) { _, _ in notes.updatedAt = Date() }
    }

    private func section<C: View>(_ title: String, icon: String, tint: Color, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: title, icon: icon, tint: tint)
            content()
        }
        .modifier(FinanceCard(glow: tint))
    }

    private func money(_ label: String, _ value: Binding<Double>, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label)
            HStack {
                Text("$").font(.title3.bold()).foregroundStyle(tint)
                TextField("0.00", value: value, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .font(.title3.bold())
            }
            .cosmicField()
        }
    }
}
