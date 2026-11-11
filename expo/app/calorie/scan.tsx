import { invalidateFoodLogs } from '../../services/queryInvalidationService';
import React, { useState, useRef, useCallback } from 'react';
import { View, StyleSheet, Text, ActivityIndicator, ScrollView, TextInput, Alert, Dimensions } from 'react-native';
import { TouchableOpacity } from '@/components/HapticTouchable';
import { useRouter } from 'expo-router';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import {
  Camera,
  X,
  Sparkles,
  Check,
  RotateCcw,
  ChevronDown,
  Info,
  ShieldCheck,
} from 'lucide-react-native';
import { foodLogsDb, appointmentsDb } from '@/lib/db';
import { sendFoodLogToAppleHealth } from '@/lib/healthkit';
import { getAutoMealType, parseOptionalNumber } from '@/services/calorieAnalysisService';
import { lookupBarcodeProduct } from '@/services/barcodeLookupService';
import type { FoodLog, MealType, Appointment } from '@/types';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

const MEAL_TYPES: { value: MealType; label: string; icon: string; timeRange: string }[] = [
  { value: 'breakfast', label: 'Breakfast', icon: '🌅', timeRange: '5am-11am' },
  { value: 'lunch', label: 'Lunch', icon: '☀️', timeRange: '11am-3pm' },
  { value: 'dinner', label: 'Dinner', icon: '🌙', timeRange: '5pm-10pm' },
  { value: 'snack', label: 'Snack', icon: '🍎', timeRange: 'Anytime' },
];

export default function FoodBarcodeScannerScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const insets = useSafeAreaInsets();

  const [permission, requestPermission] = useCameraPermissions();
  const [barcodeData, setBarcodeData] = useState<string | null>(null);
  const [barcodeFoodName, setBarcodeFoodName] = useState('');
  const [barcodeCalories, setBarcodeCalories] = useState('');
  const [barcodeProtein, setBarcodeProtein] = useState('');
  const [barcodeCarbs, setBarcodeCarbs] = useState('');
  const [barcodeFat, setBarcodeFat] = useState('');
  const [barcodeFiber, setBarcodeFiber] = useState('');
  const [barcodeMealType, setBarcodeMealType] = useState<MealType>(getAutoMealType());
  const [showBarcodeMealPicker, setShowBarcodeMealPicker] = useState(false);
  const [barcodeLookup, setBarcodeLookup] = useState<'idle' | 'loading' | 'found' | 'not-found'>('idle');
  const barcodeLockRef = useRef(false);

  const closeBarcodeEntry = useCallback(() => {
    barcodeLockRef.current = false;
    setBarcodeLookup('idle');
    setBarcodeData(null);
  }, []);

  const handleBarcodeScanned = useCallback(async ({ data }: { data: string }) => {
    if (barcodeLockRef.current) return;
    barcodeLockRef.current = true;

    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setBarcodeData(data);
    setBarcodeLookup('loading');

    const product = await lookupBarcodeProduct(data);
    if (!product) {
      setBarcodeLookup('not-found');
      return;
    }

    setBarcodeFoodName(product.brand ? `${product.brand} ${product.name}` : product.name);
    setBarcodeCalories(product.calories != null ? String(product.calories) : '');
    setBarcodeProtein(product.protein != null ? String(product.protein) : '');
    setBarcodeCarbs(product.carbs != null ? String(product.carbs) : '');
    setBarcodeFat(product.fat != null ? String(product.fat) : '');
    setBarcodeFiber(product.fiber != null ? String(product.fiber) : '');
    setBarcodeLookup('found');
  }, []);

  const barcodeSaveMutation = useMutation({
    mutationFn: async () => {
      if (!barcodeData || !barcodeFoodName.trim() || !barcodeCalories.trim()) return;

      const calories = parseFloat(barcodeCalories);
      if (isNaN(calories)) return;

      const log: FoodLog = {
        id: `${Date.now()}-${Math.random().toString(36).substring(2, 11)}`,
        foodName: barcodeFoodName.trim(),
        servingDescription: '1 serving (barcode scanned)',
        calories,
        proteinGrams: parseOptionalNumber(barcodeProtein),
        carbGrams: parseOptionalNumber(barcodeCarbs),
        fatGrams: parseOptionalNumber(barcodeFat),
        sugarGrams: null,
        fiberGrams: parseOptionalNumber(barcodeFiber),
        mealType: barcodeMealType,
        sourceType: 'barcode',
        loggedAt: Date.now(),
        isLocked: true,
        calendarEventId: null,
      };

      const calendarEventId = `cal-${Date.now()}`;
      const loggedDate = new Date(log.loggedAt);
      const timeStr = loggedDate.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });

      const calendarEvent: Appointment = {
        id: calendarEventId,
        title: `${log.foodName} (${log.mealType})`,
        date: new Date(loggedDate.getFullYear(), loggedDate.getMonth(), loggedDate.getDate()).getTime(),
        time: timeStr,
        category: 'nutrition',
        notes: `${log.calories} cal | Barcode: ${barcodeData} | P: ${log.proteinGrams || 0}g C: ${log.carbGrams || 0}g F: ${log.fatGrams || 0}g`,
        reminder: false,
        createdAt: Date.now(),
        metadata: JSON.stringify({
          foodLogId: log.id,
          barcode: barcodeData,
          calories: log.calories,
          protein: log.proteinGrams,
          carbs: log.carbGrams,
          fat: log.fatGrams,
          fiber: log.fiberGrams,
          source: 'barcode',
          isLocked: log.isLocked,
        }),
      };

      await appointmentsDb.create(calendarEvent);
      const savedLog = { ...log, calendarEventId };
      await foodLogsDb.create(savedLog);
      // Mirror the scanned food to Apple Health when the user has it on.
      await sendFoodLogToAppleHealth(savedLog);
      return log;
    },
    onSuccess: () => {
      invalidateFoodLogs(queryClient);
      queryClient.invalidateQueries({ queryKey: ['appointments'] });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      closeBarcodeEntry();
      setBarcodeFoodName('');
      setBarcodeCalories('');
      setBarcodeProtein('');
      setBarcodeCarbs('');
      setBarcodeFat('');
      setBarcodeFiber('');
      router.back();
    },
    onError: (error) => {
      console.error('Barcode save error:', error);
      Alert.alert('Error', 'Failed to save barcode food entry. Please try again.');
    },
  });

  const handleBarcodeSave = useCallback(() => {
    if (!barcodeFoodName.trim()) {
      Alert.alert('Error', 'Please enter a food name');
      return;
    }
    if (!barcodeCalories.trim() || isNaN(parseFloat(barcodeCalories))) {
      Alert.alert('Error', 'Please enter valid calories');
      return;
    }
    barcodeSaveMutation.mutate();
  }, [barcodeFoodName, barcodeCalories, barcodeSaveMutation]);

  if (!permission) {
    return (
      <View style={[styles.container, styles.centered]}>
        <ActivityIndicator size="large" color="#6366f1" />
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={[styles.container, { paddingTop: insets.top }]}>
        <LinearGradient
          colors={['#0a0a0f', '#0d0d15', '#0a0a0f']}
          style={StyleSheet.absoluteFill}
        />
        <View style={styles.permissionContent}>
          <View style={styles.permissionIconContainer}>
            <Camera size={48} color="#6366f1" />
          </View>
          <Text style={styles.permissionTitle}>Camera Access</Text>
          <Text style={styles.permissionText}>
            Allow camera access to scan a food barcode and log the nutrition automatically
          </Text>
          <TouchableOpacity style={styles.permissionButton} onPress={requestPermission}>
            <Text style={styles.permissionButtonText}>Enable Camera</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  if (barcodeData) {
    return (
      <View style={styles.container}>
        <LinearGradient
          colors={['#0a0a0f', '#0d0d15', '#0a0a0f']}
          style={StyleSheet.absoluteFill}
        />

        <View style={[styles.header, { paddingTop: insets.top + 8 }]}>
          <TouchableOpacity onPress={closeBarcodeEntry} style={styles.headerBtn}>
            <RotateCcw size={22} color="#fff" />
          </TouchableOpacity>
          <View style={styles.headerCenter}>
            <Text style={styles.headerTitle}>Barcode Entry</Text>
            <Text style={styles.headerSubtitle}>Code: {barcodeData}</Text>
          </View>
          <TouchableOpacity onPress={() => router.back()} style={styles.headerBtn}>
            <X size={22} color="#fff" />
          </TouchableOpacity>
        </View>

        <ScrollView
          style={styles.resultsScroll}
          contentContainerStyle={[styles.resultsContent, { paddingBottom: insets.bottom + 24 }]}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.barcodeInfoCard}>
            <Text style={styles.barcodeLabel}>Scanned Barcode</Text>
            <Text style={styles.barcodeValue}>{barcodeData}</Text>
            <Text style={styles.barcodeHint}>
              {barcodeLookup === 'loading'
                ? 'Looking up this product...'
                : barcodeLookup === 'found'
                  ? 'Nutrition filled in from Open Food Facts. Adjust anything that looks off.'
                  : 'Product not found in the database. Please enter the details below.'}
            </Text>
          </View>

          <View style={styles.barcodeForm}>
            <Text style={styles.sectionLabel}>Food Details</Text>
            <TextInput
              style={styles.barcodeInput}
              value={barcodeFoodName}
              onChangeText={setBarcodeFoodName}
              placeholder="Food name (e.g., Organic Oats)"
              placeholderTextColor="#555"
              testID="barcode-name"
            />
            <TextInput
              style={styles.barcodeInput}
              value={barcodeCalories}
              onChangeText={setBarcodeCalories}
              placeholder="Calories"
              placeholderTextColor="#555"
              keyboardType="decimal-pad"
              testID="barcode-calories"
            />
            <View style={styles.barcodeMacrosRow}>
              <TextInput
                style={[styles.barcodeInput, styles.barcodeMacroInput]}
                value={barcodeProtein}
                onChangeText={setBarcodeProtein}
                placeholder="Protein (g)"
                placeholderTextColor="#555"
                keyboardType="decimal-pad"
              />
              <TextInput
                style={[styles.barcodeInput, styles.barcodeMacroInput]}
                value={barcodeCarbs}
                onChangeText={setBarcodeCarbs}
                placeholder="Carbs (g)"
                placeholderTextColor="#555"
                keyboardType="decimal-pad"
              />
              <TextInput
                style={[styles.barcodeInput, styles.barcodeMacroInput]}
                value={barcodeFat}
                onChangeText={setBarcodeFat}
                placeholder="Fat (g)"
                placeholderTextColor="#555"
                keyboardType="decimal-pad"
              />
            </View>
            <TextInput
              style={styles.barcodeInput}
              value={barcodeFiber}
              onChangeText={setBarcodeFiber}
              placeholder="Fiber (g) - optional"
              placeholderTextColor="#555"
              keyboardType="decimal-pad"
            />
          </View>

          <View style={styles.mealTypeSelector}>
            <Text style={styles.sectionLabel}>Log to</Text>
            <TouchableOpacity
              style={styles.mealTypeButton}
              onPress={() => setShowBarcodeMealPicker(!showBarcodeMealPicker)}
            >
              <Text style={styles.mealTypeEmoji}>
                {MEAL_TYPES.find(m => m.value === barcodeMealType)?.icon}
              </Text>
              <View style={styles.mealTypeInfo}>
                <Text style={styles.mealTypeText}>
                  {MEAL_TYPES.find(m => m.value === barcodeMealType)?.label}
                </Text>
              </View>
              <ChevronDown size={18} color="#666" />
            </TouchableOpacity>

            {showBarcodeMealPicker && (
              <View style={styles.mealPickerDropdown}>
                {MEAL_TYPES.map((meal) => (
                  <TouchableOpacity
                    key={meal.value}
                    style={[
                      styles.mealPickerItem,
                      barcodeMealType === meal.value && styles.mealPickerItemSelected,
                    ]}
                    onPress={() => {
                      setBarcodeMealType(meal.value);
                      setShowBarcodeMealPicker(false);
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                    }}
                  >
                    <Text style={styles.mealPickerEmoji}>{meal.icon}</Text>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.mealPickerText}>{meal.label}</Text>
                      <Text style={styles.mealPickerTime}>{meal.timeRange}</Text>
                    </View>
                    {barcodeMealType === meal.value && <Check size={18} color="#6366f1" />}
                  </TouchableOpacity>
                ))}
              </View>
            )}
          </View>

          <TouchableOpacity
            style={styles.saveButton}
            onPress={handleBarcodeSave}
            disabled={barcodeSaveMutation.isPending}
            testID="save-barcode-food"
          >
            {barcodeSaveMutation.isPending ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <>
                <ShieldCheck size={20} color="#fff" />
                <Text style={styles.saveButtonText}>Log Food</Text>
              </>
            )}
          </TouchableOpacity>
        </ScrollView>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* No barcodeScannerSettings: expo-camera then accepts every format it
          supports (EAN/UPC, Code 128/39, ITF, QR, Data Matrix, PDF417, ...), so
          any food product barcode scans instead of only a hardcoded few. */}
      <CameraView
        style={styles.camera}
        facing="back"
        onBarcodeScanned={handleBarcodeScanned}
      >
        <LinearGradient
          colors={['rgba(0,0,0,0.7)', 'transparent', 'transparent', 'rgba(0,0,0,0.7)']}
          style={StyleSheet.absoluteFill}
        />

        <View style={[styles.cameraHeader, { paddingTop: insets.top + 8 }]}>
          <TouchableOpacity onPress={() => router.back()} style={styles.closeBtn} testID="close-camera">
            <X size={26} color="#fff" />
          </TouchableOpacity>
          <View style={styles.cameraTitleGroup}>
            <Text style={styles.cameraTitle}>Food Barcode Scanner</Text>
            <Text style={styles.cameraSubtitle}>Align the barcode in frame</Text>
          </View>
          <View style={styles.closeBtnPlaceholder} />
        </View>

        <View style={styles.scanFrameContainer}>
          <View style={styles.barcodeFrame}>
            <View style={[styles.barcodeCorner, styles.barcodeCornerTL]} />
            <View style={[styles.barcodeCorner, styles.barcodeCornerTR]} />
            <View style={[styles.barcodeCorner, styles.barcodeCornerBL]} />
            <View style={[styles.barcodeCorner, styles.barcodeCornerBR]} />
          </View>
          <View style={styles.scanHintContainer}>
            <Sparkles size={16} color="rgba(255,255,255,0.7)" />
            <Text style={styles.scanHint}>Scanning any barcode format</Text>
          </View>
        </View>

        <View style={styles.tipsBanner}>
          <Info size={14} color="#6366f1" />
          <Text style={styles.tipText}>
            Tip: Hold steady and keep the whole barcode in focus
          </Text>
        </View>

        <View style={[styles.cameraControls, { paddingBottom: insets.bottom + 32 }]}>
          <View style={styles.scanningIndicator}>
            <ActivityIndicator size="small" color="#fff" />
            <Text style={styles.controlLabel}>Scanning</Text>
          </View>
        </View>
      </CameraView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0f',
  },
  centered: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  camera: {
    flex: 1,
  },
  permissionContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
    gap: 16,
  },
  permissionIconContainer: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: 'rgba(99, 102, 241, 0.12)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  permissionTitle: {
    fontSize: 22,
    fontWeight: '700' as const,
    color: '#fff',
  },
  permissionText: {
    fontSize: 14,
    color: '#888',
    textAlign: 'center' as const,
    lineHeight: 20,
  },
  permissionButton: {
    marginTop: 8,
    backgroundColor: '#6366f1',
    borderRadius: 14,
    paddingHorizontal: 28,
    paddingVertical: 14,
  },
  permissionButtonText: {
    fontSize: 16,
    fontWeight: '700' as const,
    color: '#fff',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingBottom: 12,
  },
  headerBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.06)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerCenter: {
    alignItems: 'center',
    flex: 1,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '700' as const,
    color: '#fff',
  },
  headerSubtitle: {
    fontSize: 12,
    color: '#888',
    marginTop: 2,
  },
  resultsScroll: {
    flex: 1,
  },
  resultsContent: {
    paddingHorizontal: 16,
    paddingTop: 8,
  },
  barcodeInfoCard: {
    backgroundColor: 'rgba(99, 102, 241, 0.1)',
    borderRadius: 16,
    padding: 20,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: 'rgba(99, 102, 241, 0.2)',
    gap: 8,
  },
  barcodeLabel: {
    fontSize: 12,
    color: '#888',
    fontWeight: '600' as const,
    textTransform: 'uppercase' as const,
    letterSpacing: 0.5,
  },
  barcodeValue: {
    fontSize: 18,
    fontWeight: '700' as const,
    color: '#fff',
  },
  barcodeHint: {
    fontSize: 13,
    color: '#666',
    marginTop: 4,
    lineHeight: 18,
  },
  barcodeForm: {
    gap: 12,
    marginBottom: 20,
  },
  barcodeInput: {
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderRadius: 12,
    padding: 14,
    fontSize: 16,
    color: '#fff',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.06)',
  },
  barcodeMacrosRow: {
    flexDirection: 'row',
    gap: 10,
  },
  barcodeMacroInput: {
    flex: 1,
  },
  sectionLabel: {
    fontSize: 13,
    fontWeight: '600' as const,
    color: '#888',
    marginBottom: 4,
    textTransform: 'uppercase' as const,
    letterSpacing: 0.5,
  },
  barcodeFrame: {
    width: SCREEN_WIDTH * 0.8,
    height: 120,
    position: 'relative',
    borderRadius: 8,
  },
  barcodeCorner: {
    position: 'absolute',
    width: 30,
    height: 30,
    borderColor: '#6366f1',
  },
  barcodeCornerTL: {
    top: 0,
    left: 0,
    borderTopWidth: 4,
    borderLeftWidth: 4,
    borderTopLeftRadius: 8,
  },
  barcodeCornerTR: {
    top: 0,
    right: 0,
    borderTopWidth: 4,
    borderRightWidth: 4,
    borderTopRightRadius: 8,
  },
  barcodeCornerBL: {
    bottom: 0,
    left: 0,
    borderBottomWidth: 4,
    borderLeftWidth: 4,
    borderBottomLeftRadius: 8,
  },
  barcodeCornerBR: {
    bottom: 0,
    right: 0,
    borderBottomWidth: 4,
    borderRightWidth: 4,
    borderBottomRightRadius: 8,
  },
  cameraHeader: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    zIndex: 10,
  },
  closeBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(0,0,0,0.4)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeBtnPlaceholder: {
    width: 44,
  },
  cameraTitleGroup: {
    alignItems: 'center',
  },
  cameraTitle: {
    fontSize: 18,
    fontWeight: '700' as const,
    color: '#fff',
  },
  cameraSubtitle: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.6)',
    marginTop: 2,
  },
  scanFrameContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  scanHintContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginTop: 24,
    backgroundColor: 'rgba(0,0,0,0.4)',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
  },
  scanHint: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.8)',
    fontWeight: '500' as const,
  },
  tipsBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginHorizontal: 20,
    marginBottom: 16,
    backgroundColor: 'rgba(99, 102, 241, 0.15)',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
  },
  tipText: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.75)',
    flex: 1,
  },
  cameraControls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  scanningIndicator: {
    alignItems: 'center',
    gap: 8,
  },
  controlLabel: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.7)',
    fontWeight: '600' as const,
  },
  mealTypeSelector: {
    marginBottom: 20,
  },
  mealTypeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderRadius: 14,
    padding: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.06)',
  },
  mealTypeEmoji: {
    fontSize: 20,
  },
  mealTypeInfo: {
    flex: 1,
  },
  mealTypeText: {
    fontSize: 16,
    fontWeight: '600' as const,
    color: '#fff',
  },
  mealPickerDropdown: {
    marginTop: 8,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderRadius: 14,
    overflow: 'hidden',
  },
  mealPickerItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 14,
  },
  mealPickerItemSelected: {
    backgroundColor: 'rgba(99, 102, 241, 0.12)',
  },
  mealPickerEmoji: {
    fontSize: 18,
  },
  mealPickerText: {
    fontSize: 15,
    fontWeight: '600' as const,
    color: '#fff',
  },
  mealPickerTime: {
    fontSize: 12,
    color: '#666',
    marginTop: 2,
  },
  saveButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: '#6366f1',
    borderRadius: 16,
    paddingVertical: 16,
    marginTop: 4,
  },
  saveButtonText: {
    fontSize: 16,
    fontWeight: '700' as const,
    color: '#fff',
  },
});
