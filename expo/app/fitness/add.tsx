import React, { useState } from 'react';
import { View, StyleSheet, TextInput, Text, ScrollView, Alert, Platform, KeyboardAvoidingView } from 'react-native';
import { TouchableOpacity } from '@/components/HapticTouchable';
import { useRouter } from 'expo-router';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ChevronLeft } from 'lucide-react-native';
import * as Haptics from 'expo-haptics';
import { workoutTemplatesDb, workoutSessionsDb, normalizedMetricsDb } from '@/lib/db/fitness';
import { estimateCalories } from '@/lib/fitness';
import { sendWorkoutToAppleHealth } from '@/lib/healthkit';
import type { WorkoutSession, WorkoutTemplate } from '@/types';

const WORKOUT_TYPE_MAP: Record<string, WorkoutTemplate['category']> = {
  cardio: 'hiit',
  strength: 'strength',
  yoga: 'yoga',
  hiit: 'hiit',
  stretching: 'stretch',
  sports: 'run',
  other: 'stretch',
};

const WORKOUT_TYPE_INTENSITY: Record<string, WorkoutTemplate['intensity']> = {
  cardio: 'medium',
  strength: 'high',
  yoga: 'low',
  hiit: 'high',
  stretching: 'low',
  sports: 'medium',
  other: 'low',
};

export default function AddWorkoutScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const [type, setType] = useState<'cardio' | 'strength' | 'yoga' | 'hiit' | 'stretching' | 'sports' | 'other'>('cardio');
  const [duration, setDuration] = useState('');
  const [notes, setNotes] = useState('');
  const [workoutDescription, setWorkoutDescription] = useState('');
  const [calories, setCalories] = useState('');

  const createMutation = useMutation({
    mutationFn: async () => {
      const durationNum = parseInt(duration, 10);
      if (isNaN(durationNum) || durationNum <= 0) {
        throw new Error('Invalid duration');
      }

      const category = WORKOUT_TYPE_MAP[type];
      const intensity = WORKOUT_TYPE_INTENSITY[type];
      // A typed figure wins; otherwise fall back to the local duration/intensity estimate.
      const enteredCalories = parseInt(calories, 10);
      const caloriesBurned =
        !isNaN(enteredCalories) && enteredCalories > 0
          ? enteredCalories
          : estimateCalories(durationNum, intensity);

      const templateId = `manual-${Date.now()}`;
      const template: WorkoutTemplate = {
        id: templateId,
        title: workoutDescription.trim() || `${type.charAt(0).toUpperCase() + type.slice(1)} Workout`,
        category,
        durationMinutes: durationNum,
        intensity,
        equipment: 'none',
        description: notes.trim() || `Manual ${type} workout`,
      };

      await workoutTemplatesDb.create(template);

      const now = Date.now();
      const session: WorkoutSession = {
        id: `session-${Date.now()}`,
        templateId,
        startedAt: now - durationNum * 60 * 1000,
        endedAt: now,
        durationMinutes: durationNum,
        completed: true,
        caloriesEstimate: caloriesBurned,
        source: 'manual',
      };

      await workoutSessionsDb.create(session);

      const dateStr = new Date().toISOString().split('T')[0];
      const existingMetric = await normalizedMetricsDb.getByDate(dateStr);
      if (existingMetric) {
        // upsert() adds to the stored totals, so pass this workout's own figures
        // as the delta — pre-adding the existing values would double them.
        await normalizedMetricsDb.upsert({
          id: existingMetric.id,
          date: dateStr,
          activeMinutes: durationNum,
          caloriesActive: caloriesBurned,
          steps: 0,
          source: 'workout',
          deviceType: 'none',
        });
      } else {
        await normalizedMetricsDb.create({
          id: `metric-${Date.now()}`,
          date: dateStr,
          activeMinutes: durationNum,
          caloriesActive: caloriesBurned,
          steps: 0,
          source: 'workout',
          deviceType: 'none',
        });
      }

      // Mirror the finished workout to Apple Health when the user has it on.
      await sendWorkoutToAppleHealth(session);

      return session;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['workoutSessions'] });
      queryClient.invalidateQueries({ queryKey: ['workoutTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['todayMetric'] });
      queryClient.invalidateQueries({ queryKey: ['fitnessAwards'] });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      router.back();
    },
    onError: (error) => {
      console.error('Workout save error:', error);
      Alert.alert('Error', 'Failed to save workout. Please try again.');
    },
  });

  const handleSave = () => {
    if (!duration.trim() || isNaN(parseInt(duration)) || parseInt(duration) <= 0) {
      Alert.alert('Error', 'Please enter a valid duration in minutes');
      return;
    }

    createMutation.mutate();
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backBtn}>
          <ChevronLeft size={24} color="#fff" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Log Workout</Text>
        <View style={styles.backBtn} />
      </View>

      <KeyboardAvoidingView style={styles.scrollView} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 0}>
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <Text style={styles.label}>Workout Type</Text>
        <View style={styles.typeContainer}>
          {(['cardio', 'strength', 'yoga', 'hiit', 'stretching', 'sports', 'other'] as const).map((t) => (
            <TouchableOpacity
              key={t}
              style={[styles.typeChip, type === t && styles.typeChipActive]}
              onPress={() => setType(t)}
            >
              <Text style={[styles.typeText, type === t && styles.typeTextActive]}>
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={styles.label}>Duration (minutes)</Text>
        <TextInput
          style={styles.input}
          value={duration}
          onChangeText={setDuration}
          placeholder="30"
          placeholderTextColor="#666"
          keyboardType="number-pad"
        />

        <Text style={styles.label}>Workout Description</Text>
        <TextInput
          style={[styles.input, styles.textArea]}
          value={workoutDescription}
          onChangeText={setWorkoutDescription}
          placeholder="e.g. 'Running on treadmill at 6mph with 2% incline' or '3 sets of 10 squats, deadlifts, and bench press'"
          placeholderTextColor="#555"
          multiline
          numberOfLines={4}
          textAlignVertical="top"
        />

        <Text style={styles.label}>Calories Burned (optional)</Text>
        <TextInput
          style={styles.input}
          value={calories}
          onChangeText={setCalories}
          placeholder="Leave blank for an estimate"
          placeholderTextColor="#666"
          keyboardType="number-pad"
        />
        <Text style={styles.sublabel}>
          Enter your own figure, or leave it blank and Alchemize estimates from duration and intensity.
        </Text>

        <Text style={styles.label}>Additional Notes (optional)</Text>
        <TextInput
          style={[styles.input, styles.smallTextArea]}
          value={notes}
          onChangeText={setNotes}
          placeholder="Any other details..."
          placeholderTextColor="#666"
          multiline
          numberOfLines={2}
          textAlignVertical="top"
        />

        <TouchableOpacity
          style={styles.saveButton}
          onPress={handleSave}
          disabled={createMutation.isPending}
        >
          <Text style={styles.saveButtonText}>
            {createMutation.isPending ? 'Saving...' : 'Log Workout'}
          </Text>
        </TouchableOpacity>
      </ScrollView>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 60,
    paddingBottom: 16,
  },
  backBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '700' as const,
    color: '#fff',
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: 20,
    paddingTop: 0,
    paddingBottom: 40,
  },
  label: {
    fontSize: 16,
    fontWeight: '600' as const,
    color: '#fff',
    marginBottom: 8,
    marginTop: 16,
  },
  input: {
    backgroundColor: '#1a1a1a',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    color: '#fff',
    borderWidth: 1,
    borderColor: '#2a2a2a',
  },
  textArea: {
    minHeight: 100,
    paddingTop: 16,
  },
  smallTextArea: {
    minHeight: 60,
    paddingTop: 12,
  },
  sublabel: {
    fontSize: 13,
    color: '#666',
    marginBottom: 8,
    marginTop: -4,
  },
  saveButton: {
    backgroundColor: '#6366f1',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginTop: 32,
    marginBottom: 40,
  },
  saveButtonText: {
    fontSize: 16,
    fontWeight: '600' as const,
    color: '#fff',
  },
  typeContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  typeChip: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#1a1a1a',
    borderWidth: 1,
    borderColor: '#2a2a2a',
  },
  typeChipActive: {
    backgroundColor: '#6366f1',
    borderColor: '#6366f1',
  },
  typeText: {
    fontSize: 13,
    color: '#a0a0a0',
    fontWeight: '500' as const,
  },
  typeTextActive: {
    color: '#fff',
  },
});
