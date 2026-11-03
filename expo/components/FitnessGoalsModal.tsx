import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Modal, Pressable, TextInput, KeyboardAvoidingView, Platform } from 'react-native';
import { TouchableOpacity } from '@/components/HapticTouchable';
import { X, Timer, Flame, Footprints } from 'lucide-react-native';

export interface FitnessGoalTargets {
  activeMinutes: number;
  calories: number;
  steps: number;
}

interface FitnessGoalsModalProps {
  visible: boolean;
  initial: FitnessGoalTargets;
  saving?: boolean;
  onClose: () => void;
  onSave: (targets: FitnessGoalTargets) => void;
}

const FIELDS = [
  { key: 'activeMinutes', label: 'Active Minutes', icon: Timer, color: '#10b981', hint: 'Daily minutes of activity' },
  { key: 'calories', label: 'Calories', icon: Flame, color: '#f59e0b', hint: 'Daily calories burned' },
  { key: 'steps', label: 'Steps', icon: Footprints, color: '#3b82f6', hint: 'Daily step target' },
] as const;

type FieldKey = typeof FIELDS[number]['key'];

export default function FitnessGoalsModal({ visible, initial, saving = false, onClose, onSave }: FitnessGoalsModalProps) {
  const [draft, setDraft] = useState<Record<FieldKey, string>>({
    activeMinutes: String(initial.activeMinutes),
    calories: String(initial.calories),
    steps: String(initial.steps),
  });

  useEffect(() => {
    if (!visible) return;
    setDraft({
      activeMinutes: String(initial.activeMinutes),
      calories: String(initial.calories),
      steps: String(initial.steps),
    });
  }, [visible, initial.activeMinutes, initial.calories, initial.steps]);

  const parsed = {
    activeMinutes: parseInt(draft.activeMinutes, 10),
    calories: parseInt(draft.calories, 10),
    steps: parseInt(draft.steps, 10),
  };
  const isValid = FIELDS.every(f => Number.isFinite(parsed[f.key]) && parsed[f.key] > 0);

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <Pressable style={styles.overlay} onPress={onClose}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <Pressable style={styles.sheet} onPress={(e) => e.stopPropagation()}>
            <View style={styles.header}>
              <Text style={styles.title}>Edit Daily Goals</Text>
              <TouchableOpacity onPress={onClose} testID="goals-close">
                <X size={22} color="rgba(255,255,255,0.7)" />
              </TouchableOpacity>
            </View>
            <Text style={styles.subtitle}>Set your own targets for each metric.</Text>

            {FIELDS.map((field) => {
              const Icon = field.icon;
              return (
                <View key={field.key} style={styles.field}>
                  <View style={styles.fieldLabelRow}>
                    <Icon size={16} color={field.color} />
                    <Text style={styles.fieldLabel}>{field.label}</Text>
                  </View>
                  <TextInput
                    style={styles.input}
                    value={draft[field.key]}
                    onChangeText={(text) => setDraft(prev => ({ ...prev, [field.key]: text.replace(/[^0-9]/g, '') }))}
                    keyboardType="number-pad"
                    inputMode="numeric"
                    placeholder={field.hint}
                    placeholderTextColor="rgba(255,255,255,0.3)"
                    testID={`goal-input-${field.key}`}
                  />
                </View>
              );
            })}

            <View style={styles.actions}>
              <TouchableOpacity style={styles.cancelBtn} onPress={onClose} testID="goals-cancel">
                <Text style={styles.cancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.saveBtn, (!isValid || saving) && styles.saveBtnDisabled]}
                onPress={() => onSave(parsed)}
                disabled={!isValid || saving}
                testID="goals-save"
              >
                <Text style={styles.saveText}>{saving ? 'Saving...' : 'Save Goals'}</Text>
              </TouchableOpacity>
            </View>
          </Pressable>
        </KeyboardAvoidingView>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.75)',
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: 'rgba(20,20,26,0.99)',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    padding: 20,
    paddingBottom: 32,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    color: '#fff',
  },
  subtitle: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.6)',
    marginTop: 4,
    marginBottom: 16,
  },
  field: {
    marginBottom: 14,
  },
  fieldLabelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 6,
  },
  fieldLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: 'rgba(255,255,255,0.85)',
  },
  input: {
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
    color: '#fff',
  },
  actions: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 8,
  },
  cancelBtn: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 14,
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
  cancelText: {
    fontSize: 15,
    fontWeight: '600',
    color: 'rgba(255,255,255,0.8)',
  },
  saveBtn: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 14,
    alignItems: 'center',
    backgroundColor: '#10b981',
  },
  saveBtnDisabled: {
    opacity: 0.5,
  },
  saveText: {
    fontSize: 15,
    fontWeight: '700',
    color: '#fff',
  },
});
