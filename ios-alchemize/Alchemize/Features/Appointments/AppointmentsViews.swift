import SwiftUI
import SwiftData

private func categoryColor(_ c: String) -> Color { c == "business" ? AZ.green : AZ.blue }
private func categoryIcon(_ c: String) -> String { c == "business" ? "briefcase.fill" : "person.fill" }

struct AppointmentsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Appointment.date) private var appointments: [Appointment]
    @State private var month = Date()
    @State private var selected = Date().startOfDay
    @State private var showAdd = false
    @State private var editing: Appointment?
    @State private var detail: Appointment?

    private var dayItems: [Appointment] {
        appointments.filter { Calendar.current.isDate($0.date, inSameDayAs: selected) }
    }
    private var upcoming: [Appointment] {
        appointments.filter { $0.date >= Date() }.prefix(3).map { $0 }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ImageBackdrop(url: AZImages.appointmentsBackground, overlay: Color(hex: 0x050211, opacity: 0.6))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MonthCalendarView(month: $month, selected: selected, accent: AZ.violetLight,
                                      marked: { d in appointments.contains { Calendar.current.isDate($0.date, inSameDayAs: d) } }) { day in
                        withAnimation(.snappy) { selected = day.startOfDay }
                    }
                    .glassCard(radius: 22)

                    HStack {
                        Text(Calendar.current.isDateInToday(selected) ? "Today" : selected.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.title3.bold()).foregroundStyle(.white)
                        Spacer()
                        Text("\(dayItems.count)").font(.subheadline.weight(.bold)).foregroundStyle(AZ.violetLight)
                            .contentTransition(.numericText())
                    }

                    if dayItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus").font(.system(size: 40)).foregroundStyle(AZ.violetLight)
                            Text("No appointments for this day").foregroundStyle(AZ.textSecondary)
                            Button { showAdd = true } label: {
                                Label("Add Appointment", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 18).frame(height: 42)
                                    .background(AZ.fabGradient, in: .capsule)
                            }
                            .buttonStyle(.squish)
                        }
                        .frame(maxWidth: .infinity)
                        .glassCard(radius: 20)
                    } else {
                        ForEach(dayItems) { a in
                            Button { detail = a } label: { row(a) }
                                .buttonStyle(.squish(0.98))
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }

                    if !upcoming.isEmpty {
                        Text("Upcoming").font(.headline).foregroundStyle(.white.opacity(0.85)).padding(.top, 8)
                        ForEach(upcoming) { a in
                            Button {
                                withAnimation(.snappy) { selected = a.date.startOfDay; month = a.date }
                            } label: { row(a, compact: true) }
                            .buttonStyle(.squish(0.98))
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            FloatingAddButton { showAdd = true }.padding(24)
        }
        .cosmicNavigation("Appointments")
        .sheet(isPresented: $showAdd) { AppointmentEditor(appointment: nil, initialDate: selected) }
        .sheet(item: $editing) { AppointmentEditor(appointment: $0, initialDate: $0.date) }
        .sheet(item: $detail) { a in
            AppointmentDetailSheet(appointment: a, onEdit: {
                detail = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editing = a }
            }, onDelete: {
                Notifications.cancel(a.notificationId)
                detail = nil
                withAnimation { context.delete(a) }
                Haptics.warning()
            })
        }
    }

    private func row(_ a: Appointment, compact: Bool = false) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3).fill(categoryColor(a.category)).frame(width: 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(a.title).font(.headline).foregroundStyle(.white).multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    Label(compact ? a.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()) : a.date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    Label(a.category.capitalized, systemImage: categoryIcon(a.category)).foregroundStyle(categoryColor(a.category))
                }
                .font(.caption)
                .foregroundStyle(AZ.textSecondary)
            }
            Spacer()
            if a.reminder { Image(systemName: "bell.fill").font(.caption).foregroundStyle(AZ.amber) }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.3))
        }
        .frame(minHeight: compact ? 44 : 56)
        .glassCard(radius: 18, padding: 14)
    }
}

private struct AppointmentDetailSheet: View {
    let appointment: Appointment
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var confirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: categoryIcon(appointment.category))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(categoryColor(appointment.category), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading) {
                    Text(appointment.title).font(.title3.bold()).foregroundStyle(.white)
                    Text(appointment.category.capitalized).font(.caption).foregroundStyle(categoryColor(appointment.category))
                }
            }
            Label(appointment.date.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                .foregroundStyle(AZ.textSecondary)
            if appointment.reminder {
                Label("Reminder set", systemImage: "bell.fill").foregroundStyle(AZ.amber).font(.subheadline)
            }
            if !appointment.notes.isEmpty {
                Text("Notes").font(.caption.weight(.bold)).foregroundStyle(AZ.lavender)
                Text(appointment.notes).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button { Haptics.tap(); onEdit() } label: {
                    Label("Edit", systemImage: "pencil").frame(maxWidth: .infinity).frame(height: 48)
                        .foregroundStyle(.white).background(AZ.indigo, in: .rect(cornerRadius: 14))
                }
                Button { confirm = true } label: {
                    Label("Delete", systemImage: "trash").frame(maxWidth: .infinity).frame(height: 48)
                        .foregroundStyle(AZ.red).background(AZ.red.opacity(0.15), in: .rect(cornerRadius: 14))
                }
            }
            .font(.headline)
            .buttonStyle(.squish)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationBackground(AZ.night)
        .presentationDragIndicator(.visible)
        .confirmationDialog("Delete this appointment?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

struct AppointmentEditor: View {
    let appointment: Appointment?
    let initialDate: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = "personal"
    @State private var date = Date()
    @State private var notes = ""
    @State private var reminder = false
    @State private var loaded = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            SheetCanvas {
                FieldLabel(text: "Title")
                TextField("Appointment title", text: $title).cosmicField()
                FieldLabel(text: "Category")
                HStack(spacing: 12) {
                    categoryButton("personal")
                    categoryButton("business")
                }
                FieldLabel(text: "Date & Time")
                DatePicker("When", selection: $date)
                    .datePickerStyle(.graphical)
                    .tint(categoryColor(category))
                    .glassCard(radius: 18, padding: 8)
                FieldLabel(text: "Notes (Optional)")
                TextField("Add any notes or details...", text: $notes, axis: .vertical).lineLimit(3...6).cosmicField()
                Toggle(isOn: $reminder) {
                    Label("Set Reminder", systemImage: "bell.fill").foregroundStyle(.white)
                }
                .tint(AZ.purple)
                .cosmicField()
                GradientButton(title: appointment == nil ? "Save Appointment" : "Update Appointment", icon: "calendar.badge.checkmark") { save() }
                    .disabled(!canSave).opacity(canSave ? 1 : 0.5)
            }
            .navigationTitle(appointment == nil ? "New Appointment" : "Edit Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save) }
        }
        .presentationBackground(AZ.night)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let a = appointment {
                title = a.title; category = a.category; date = a.date; notes = a.notes; reminder = a.reminder
            } else {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: initialDate)
                comps.hour = max(9, Calendar.current.component(.hour, from: Date()) + 1)
                date = Calendar.current.date(from: comps) ?? initialDate
            }
        }
    }

    private func categoryButton(_ c: String) -> some View {
        let on = category == c
        return Button {
            Haptics.select()
            withAnimation(.snappy) { category = c }
        } label: {
            Label(c.capitalized, systemImage: categoryIcon(c))
                .font(.headline)
                .foregroundStyle(on ? .white : categoryColor(c))
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(on ? categoryColor(c) : categoryColor(c).opacity(0.12), in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(categoryColor(c).opacity(0.5)))
        }
        .buttonStyle(.squish)
    }

    private func save() {
        guard canSave else { return }
        let target: Appointment
        if let a = appointment {
            a.title = title; a.category = category; a.date = date; a.notes = notes; a.reminder = reminder
            target = a
        } else {
            target = Appointment(title: title, date: date, category: category, notes: notes, reminder: reminder)
            context.insert(target)
        }
        Notifications.cancel(target.notificationId)
        target.notificationId = nil
        if reminder {
            let fireAt = date.addingTimeInterval(-15 * 60)
            let body = "\(title) at \(date.formatted(date: .omitted, time: .shortened))"
            Task { target.notificationId = await Notifications.schedule(title: "Upcoming appointment", body: body, at: fireAt > Date() ? fireAt : date) }
        }
        Haptics.success()
        dismiss()
    }
}
