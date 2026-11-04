import React, { useMemo, useState } from 'react';
import { View, StyleSheet, ScrollView, Text, ImageBackground, Platform, Modal, Pressable, TextInput, Alert, KeyboardAvoidingView } from 'react-native';
import { TouchableOpacity } from '@/components/HapticTouchable';
import { useRouter } from 'expo-router';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Play, TrendingUp, Award, ChevronRight, Plus, Dumbbell, Pencil, Trash2 } from 'lucide-react-native';
import FitnessGoalsModal, { type FitnessGoalTargets } from '@/components/FitnessGoalsModal';
import { workoutTemplatesDb, workoutSessionsDb, normalizedMetricsDb, fitnessGoalsDb, fitnessPlansDb, awardsDb } from '@/lib/db/fitness';
import type { Award as AwardType, WorkoutSession, NormalizedMetric, WorkoutTemplate } from '@/types';
import {
  seedWorkoutTemplates,
  seedAwards,
  getTodayProgress,
  getWeekSummary,
  recommendWorkouts,
  getWeekDays,
  markActiveDay,
} from '@/lib/fitness';
import { usePedometer } from '@/hooks/use-pedometer';
export default function FitnessHubScreen() {
  const router = useRouter();

  const { data: templates = [] } = useQuery({
    queryKey: ['workoutTemplates'],
    queryFn: async () => {
      const data = await workoutTemplatesDb.getAll();
      if (data.length === 0) {
        await seedWorkoutTemplates();
        return await workoutTemplatesDb.getAll();
      }
      return data;
    },
  });

  const { data: sessions = [] } = useQuery({
    queryKey: ['workoutSessions'],
    queryFn: () => workoutSessionsDb.getAll(),
  });
  const manualSessions = useMemo(() => sessions.filter(session => session.source === 'manual'), [sessions]);

  const { data: todayMetric } = useQuery({
    queryKey: ['todayMetric'],
    queryFn: async () => {
      const today = new Date();
      const dateStr = today.toISOString().split('T')[0];
      return await normalizedMetricsDb.getByDate(dateStr);
    },
  });

  const { data: goals = [] } = useQuery({
    queryKey: ['fitnessGoals'],
    queryFn: () => fitnessGoalsDb.getAll(),
  });

  const { data: activePlan } = useQuery({
    queryKey: ['activeFitnessPlan'],
    queryFn: () => fitnessPlansDb.getActive(),
  });

  const { data: awards = [] } = useQuery({
    queryKey: ['fitnessAwards'],
    queryFn: async () => {
      const data = await awardsDb.getAll();
      if (data.length === 0) {
        await seedAwards();
        return await awardsDb.getAll();
      }
      return data;
    },
  });

  const { steps: pedometerSteps } = usePedometer();

  const todayProgress = useMemo(() => getTodayProgress(sessions, todayMetric || null), [sessions, todayMetric]);
  const displaySteps = Math.max(todayProgress.steps, pedometerSteps);
  const weekSummary = useMemo(() => getWeekSummary(sessions), [sessions]);
  const recommended = useMemo(() => recommendWorkouts(templates, sessions, activePlan || null), [templates, sessions, activePlan]);
  const weekDays = useMemo(() => markActiveDay(getWeekDays(), sessions), [sessions]);

  const topWorkout = recommended[0];

  const earnedAwards = awards.filter((a: AwardType) => a.earnedAt !== null);
  const lockedAwards = awards.filter((a: AwardType) => a.earnedAt === null).slice(0, 3);

  const activeMinutesGoal = goals.find(g => g.metric === 'active_minutes')?.dailyTarget || 30;
  const caloriesGoal = goals.find(g => g.metric === 'calories')?.dailyTarget || 500;
  const stepsGoal = goals.find(g => g.metric === 'steps')?.dailyTarget || 10000;

  const [goalsModalVisible, setGoalsModalVisible] = useState(false);
  const [savingGoals, setSavingGoals] = useState(false);
  const [editingWorkout, setEditingWorkout] = useState<WorkoutSession | null>(null);
  const [durationDraft, setDurationDraft] = useState('');
  const [caloriesDraft, setCaloriesDraft] = useState('');
  const [savingWorkout, setSavingWorkout] = useState(false);
  const queryClient = useQueryClient();

  const refreshWorkoutQueries = async (includeTemplates = false) => {
    const refreshes = [
      queryClient.invalidateQueries({ queryKey: ['workoutSessions'] }),
      queryClient.invalidateQueries({ queryKey: ['todayMetric'] }),
    ];
    if (includeTemplates) refreshes.push(queryClient.invalidateQueries({ queryKey: ['workoutTemplates'] }));
    await Promise.all(refreshes).catch(error => console.warn('[Fitness] Could not refresh workout data:', error));
  };

  const handleSaveGoals = async (targets: FitnessGoalTargets) => {
    setSavingGoals(true);
    try {
      await Promise.all([
        fitnessGoalsDb.setTarget('active_minutes', targets.activeMinutes),
        fitnessGoalsDb.setTarget('calories', targets.calories),
        fitnessGoalsDb.setTarget('steps', targets.steps),
      ]);
      await queryClient.invalidateQueries({ queryKey: ['fitnessGoals'] });
      setGoalsModalVisible(false);
    } catch (error) {
      console.error('[Fitness] Failed to save goals:', error);
      Alert.alert('Could not save goals', error instanceof Error ? error.message : 'Please try again.');
    } finally {
      setSavingGoals(false);
    }
  };

  const handleDeleteGoals = () => {
    if (goals.length === 0) return;
    Alert.alert(
      'Remove custom goals?',
      'Your targets will return to the defaults: 30 active minutes, 500 calories, and 10,000 steps per day.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove Goals',
          style: 'destructive',
          onPress: () => {
            void (async () => {
              setSavingGoals(true);
              try {
                await fitnessGoalsDb.deleteAll();
                await queryClient.invalidateQueries({ queryKey: ['fitnessGoals'] });
                setGoalsModalVisible(false);
              } catch (error) {
                console.error('[Fitness] Failed to remove goals:', error);
                Alert.alert('Could not remove goals', error instanceof Error ? error.message : 'Please try again.');
              } finally {
                setSavingGoals(false);
              }
            })();
          },
        },
      ]
    );
  };

  const openWorkoutEditor = (session: WorkoutSession) => {
    if (session.source !== 'manual') return;
    setDurationDraft(String(session.durationMinutes));
    setCaloriesDraft(session.caloriesEstimate == null ? '' : String(session.caloriesEstimate));
    setEditingWorkout(session);
  };

  const handleSaveWorkout = async () => {
    if (!editingWorkout || savingWorkout || editingWorkout.source !== 'manual') return;
    const durationMinutes = Number.parseInt(durationDraft, 10);
    const caloriesText = caloriesDraft.trim();
    const caloriesEstimate = caloriesText.length === 0 ? null : Number.parseInt(caloriesText, 10);
    if (!Number.isInteger(durationMinutes) || durationMinutes < 1 || durationMinutes > 1440) {
      Alert.alert('Check workout duration', 'Enter a duration from 1 to 1,440 minutes.');
      return;
    }
    if (caloriesText.length > 0 && (!Number.isInteger(caloriesEstimate) || (caloriesEstimate ?? -1) < 0)) {
      Alert.alert('Check calorie estimate', 'Enter a non-negative whole number, or leave it blank.');
      return;
    }

    const updatedSession: WorkoutSession = {
      ...editingWorkout,
      durationMinutes,
      endedAt: editingWorkout.endedAt === null ? null : editingWorkout.startedAt + durationMinutes * 60_000,
      caloriesEstimate,
    };
    setSavingWorkout(true);
    let totalsWarning = false;
    try {
      await workoutSessionsDb.update(updatedSession);
      if (editingWorkout.completed) {
        try {
          const date = new Date(editingWorkout.startedAt).toISOString().slice(0, 10);
          const metric = await normalizedMetricsDb.getByDate(date);
          if (metric?.source === 'workout') {
            const minutesDelta = durationMinutes - editingWorkout.durationMinutes;
            const caloriesDelta = (caloriesEstimate ?? 0) - (editingWorkout.caloriesEstimate ?? 0);
            if (metric.activeMinutes + minutesDelta >= 0 && metric.caloriesActive + caloriesDelta >= 0) {
              if (minutesDelta !== 0 || caloriesDelta !== 0) {
                await normalizedMetricsDb.upsert({
                  id: metric.id,
                  date,
                  activeMinutes: minutesDelta,
                  caloriesActive: caloriesDelta,
                  steps: 0,
                  source: 'workout',
                  deviceType: metric.deviceType,
                });
              }
            } else {
              totalsWarning = true;
            }
          } else if (metric) {
            totalsWarning = true;
          }
        } catch (error) {
          console.warn('[Fitness] Workout saved but daily totals were not reconciled:', error);
          totalsWarning = true;
        }
      }
      await refreshWorkoutQueries();
      setEditingWorkout(null);
      if (totalsWarning) {
        Alert.alert('Workout saved', 'The workout was updated, but the daily activity total was left unchanged because it is HealthKit-backed or could not be reconciled safely.');
      }
    } catch (error) {
      console.error('[Fitness] Failed to update workout:', error);
      Alert.alert('Could not save workout', error instanceof Error ? error.message : 'Please try again.');
    } finally {
      setSavingWorkout(false);
    }
  };

  const handleDeleteWorkout = (session: WorkoutSession) => {
    if (session.source !== 'manual') return;
    const workoutTitle = templates.find(template => template.id === session.templateId)?.title ?? 'Manual workout';
    Alert.alert(
      'Delete workout?',
      `Remove "${workoutTitle}" from your workout history? This cannot be undone.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete Workout',
          style: 'destructive',
          onPress: () => {
            void (async () => {
              setSavingWorkout(true);
              const warnings: string[] = [];
              let metric: NormalizedMetric | null = null;
              let orphanTemplate: WorkoutTemplate | null = null;
              try {
                if (session.completed) {
                  try {
                    const date = new Date(session.startedAt).toISOString().slice(0, 10);
                    metric = await normalizedMetricsDb.getByDate(date);
                  } catch (error) {
                    console.warn('[Fitness] Could not read workout-day metrics:', error);
                    warnings.push('The daily total could not be checked or adjusted.');
                  }
                }
                try {
                  const userSessions = await workoutSessionsDb.getAll();
                  const isLastManualSession = session.templateId.startsWith('manual-')
                    && userSessions.filter(item => item.templateId === session.templateId).length === 1;
                  if (isLastManualSession) orphanTemplate = await workoutTemplatesDb.getById(session.templateId);
                } catch (error) {
                  console.warn('[Fitness] Manual workout template was kept:', error);
                  warnings.push('The quick-log template was kept because its references could not be checked.');
                }

                await workoutSessionsDb.delete(session.id);
                if (metric && session.completed) {
                  if (metric.source === 'workout') {
                    const minutesDelta = -session.durationMinutes;
                    const caloriesDelta = -(session.caloriesEstimate ?? 0);
                    if (metric.activeMinutes + minutesDelta >= 0 && metric.caloriesActive + caloriesDelta >= 0) {
                      try {
                        await normalizedMetricsDb.upsert({
                          id: metric.id,
                          date: metric.date,
                          activeMinutes: minutesDelta,
                          caloriesActive: caloriesDelta,
                          steps: 0,
                          source: 'workout',
                          deviceType: metric.deviceType,
                        });
                      } catch (error) {
                        console.warn('[Fitness] Workout deleted but daily total was not adjusted:', error);
                        warnings.push('The workout was deleted, but its manual-only daily total could not be adjusted.');
                      }
                    } else {
                      warnings.push('The workout was deleted, but the daily aggregate was left unchanged to avoid a negative total.');
                    }
                  } else {
                    warnings.push('The workout was deleted. Its daily total uses HealthKit data, so that aggregate was left unchanged.');
                  }
                }
                if (orphanTemplate) {
                  try {
                    await workoutTemplatesDb.delete(orphanTemplate.id);
                  } catch (error) {
                    console.warn('[Fitness] Workout deleted but its unused template was retained:', error);
                    warnings.push('The workout was deleted, but its unused quick-log template could not be removed.');
                  }
                }
                await refreshWorkoutQueries(Boolean(orphanTemplate));
                if (editingWorkout?.id === session.id) setEditingWorkout(null);
                if (warnings.length > 0) Alert.alert('Workout deleted with a note', warnings.join(' | '));
              } catch (error) {
                console.error('[Fitness] Failed to delete workout:', error);
                Alert.alert('Could not delete workout', error instanceof Error ? error.message : 'Please try again.');
              } finally {
                setSavingWorkout(false);
              }
            })();
          },
        },
      ]
    );
  };

  const handleStartWorkout = () => {
    if (!topWorkout) return;
    router.push(`/fitness/workout?templateId=${topWorkout.id}` as any);
  };

  const renderProgressRing = (value: number, goal: number, color: string, label: string) => {
    return (
      <View style={styles.progressRing}>
        <View style={styles.ringOuter}>
          <View style={[styles.ringInner, { borderColor: color, borderWidth: 6 }]}>
            <Text style={styles.ringValue}>{value}</Text>
            <Text style={styles.ringGoal}>/ {goal}</Text>
          </View>
        </View>
        <Text style={styles.ringLabel}>{label}</Text>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      <ImageBackground
        source={{ uri: 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/kflyhi3p0jh7nuw0u9n1u' }}
        style={styles.backgroundImage}
        resizeMode="cover"
      >
        <View style={styles.overlay} />
        <ScrollView style={styles.scrollView} contentContainerStyle={styles.content}>
          <View style={styles.addWorkoutSection}>
            <TouchableOpacity
              style={styles.addManualButton}
              onPress={() => router.push('/fitness/add' as any)}
              activeOpacity={0.8}
            >
              <View style={styles.addManualIcon}>
                <Dumbbell size={24} color="#fff" />
              </View>
              <View style={styles.addManualContent}>
                <Text style={styles.addManualTitle}>Log Manual Workout</Text>
                <Text style={styles.addManualSubtitle}>AI estimates calories burned</Text>
              </View>
              <Plus size={24} color="#10b981" />
            </TouchableOpacity>
            

          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Workout History</Text>
            <Text style={styles.historyNote}>Manual workouts can be edited or deleted. HealthKit workouts remain synced and read-only.</Text>
            {manualSessions.length === 0 ? (
              <Text style={styles.historyEmpty}>No manual workouts yet. Log one to see it here.</Text>
            ) : (
              manualSessions.map(session => {
                const title = templates.find(template => template.id === session.templateId)?.title ?? 'Manual workout';
                const caloriesText = session.caloriesEstimate == null ? 'No calorie estimate' : `${session.caloriesEstimate} kcal`;
                return (
                  <View key={session.id} style={styles.workoutHistoryCard}>
                    <View style={styles.workoutHistoryMain}>
                      <View style={styles.workoutHistoryIcon}>
                        <Dumbbell size={18} color="#10b981" />
                      </View>
                      <View style={styles.workoutHistoryText}>
                        <Text style={styles.workoutHistoryTitle} numberOfLines={1}>{title}</Text>
                        <Text style={styles.workoutHistoryMeta} numberOfLines={2}>
                          {new Date(session.startedAt).toLocaleDateString()} | {session.durationMinutes} min | {caloriesText}
                        </Text>
                      </View>
                    </View>
                    <View style={styles.workoutHistoryActions}>
                      <TouchableOpacity
                        style={styles.historyActionButton}
                        onPress={() => openWorkoutEditor(session)}
                        disabled={savingWorkout}
                        accessibilityRole="button"
                        accessibilityLabel={`Edit ${title}`}
                        testID={`edit-workout-${session.id}`}
                      >
                        <Pencil size={16} color="#10b981" />
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.historyActionButton, styles.historyActionDelete]}
                        onPress={() => handleDeleteWorkout(session)}
                        disabled={savingWorkout}
                        accessibilityRole="button"
                        accessibilityLabel={`Delete ${title}`}
                        testID={`delete-workout-${session.id}`}
                      >
                        <Trash2 size={16} color="#ef4444" />
                      </TouchableOpacity>
                    </View>
                  </View>
                );
              })
            )}
          </View>

          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>Today&apos;s Progress</Text>
              <TouchableOpacity style={styles.editGoalsButton} onPress={() => setGoalsModalVisible(true)} testID="edit-goals-button">
                <Pencil size={12} color="#10b981" />
                <Text style={styles.editGoalsText}>Edit Goals</Text>
              </TouchableOpacity>
            </View>
            <View style={styles.progressContainer}>
              {renderProgressRing(todayProgress.activeMinutes, activeMinutesGoal, '#10b981', 'Minutes')}
              {renderProgressRing(todayProgress.calories, caloriesGoal, '#f59e0b', 'Calories')}
              {renderProgressRing(displaySteps, stepsGoal, '#3b82f6', 'Steps')}
            </View>
          </View>

          {topWorkout && (
            <View style={styles.section}>
              <TouchableOpacity style={styles.startButton} onPress={handleStartWorkout}>
                <View style={styles.startButtonContent}>
                  <View style={styles.startIcon}>
                    <Play color="#fff" size={32} fill="#fff" />
                  </View>
                  <View style={styles.startTextContainer}>
                    <Text style={styles.startButtonTitle}>Start Workout</Text>
                    <Text style={styles.startButtonSubtitle}>{topWorkout.title} &bull; {topWorkout.durationMinutes} min</Text>
                  </View>
                  <ChevronRight color="#fff" size={24} />
                </View>
              </TouchableOpacity>
            </View>
          )}

          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>Your Week</Text>
            </View>
            <View style={styles.weekContainer}>
              {weekDays.map((day, index) => (
                <View key={index} style={styles.dayColumn}>
                  <Text style={styles.dayLabel}>{['S', 'M', 'T', 'W', 'T', 'F', 'S'][index]}</Text>
                  <View style={[styles.dayCircle, day.isActive && styles.dayCircleActive]}>
                    {day.isActive && <Text style={styles.dayCheck}>✓</Text>}
                  </View>
                </View>
              ))}
            </View>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>This Week</Text>
            <View style={styles.trendCard}>
              <View style={styles.trendRow}>
                <TrendingUp color="#10b981" size={20} />
                <Text style={styles.trendLabel}>Workouts</Text>
                <Text style={styles.trendValue}>{weekSummary.workoutsThisWeek}</Text>
              </View>
              <View style={styles.trendRow}>
                <TrendingUp color="#3b82f6" size={20} />
                <Text style={styles.trendLabel}>Total Minutes</Text>
                <Text style={styles.trendValue}>{weekSummary.totalMinutes}</Text>
              </View>
              <View style={styles.trendRow}>
                <TrendingUp color="#f59e0b" size={20} />
                <Text style={styles.trendLabel}>Consistency</Text>
                <Text style={styles.trendValue}>{weekSummary.consistency}%</Text>
              </View>
            </View>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Awards</Text>
            <View style={styles.awardsGrid}>
              {earnedAwards.slice(0, 3).map((award: AwardType) => (
                <View key={award.id} style={[styles.awardCard, styles.awardEarned]}>
                  <Award color="#f59e0b" size={24} fill="#f59e0b" />
                  <Text style={styles.awardTitle}>{award.title}</Text>
                </View>
              ))}
              {lockedAwards.map((award: AwardType) => (
                <View key={award.id} style={[styles.awardCard, styles.awardLocked]}>
                  <Award color="#666" size={24} />
                  <Text style={[styles.awardTitle, styles.awardTitleLocked]}>{award.title}</Text>
                </View>
              ))}
            </View>
          </View>

          <View style={{ height: 40 }} />
        </ScrollView>
      </ImageBackground>

      <FitnessGoalsModal
        visible={goalsModalVisible}
        initial={{ activeMinutes: activeMinutesGoal, calories: caloriesGoal, steps: stepsGoal }}
        saving={savingGoals}
        hasCustomGoals={goals.length > 0}
        onClose={() => setGoalsModalVisible(false)}
        onSave={handleSaveGoals}
        onDelete={handleDeleteGoals}
      />
      <Modal
        visible={editingWorkout !== null}
        animationType="slide"
        transparent
        onRequestClose={() => { if (!savingWorkout) setEditingWorkout(null); }}
      >
        <Pressable
          style={styles.workoutModalBackdrop}
          onPress={() => { if (!savingWorkout) setEditingWorkout(null); }}
        >
          <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.workoutModalKeyboard}>
            <Pressable style={styles.workoutModalSheet} onPress={(event) => event.stopPropagation()}>
              <View style={styles.workoutModalHeader}>
                <Text style={styles.workoutModalTitle}>Edit Workout</Text>
                <TouchableOpacity onPress={() => setEditingWorkout(null)} disabled={savingWorkout} accessibilityRole="button" accessibilityLabel="Close workout editor">
                  <Text style={styles.workoutModalClose}>Close</Text>
                </TouchableOpacity>
              </View>
              <Text style={styles.workoutModalSubtitle}>
                {editingWorkout ? (templates.find(template => template.id === editingWorkout.templateId)?.title ?? 'Manual workout') : 'Manual workout'}
                {' '}| Update the duration or calorie estimate.
              </Text>
              <View style={styles.workoutModalField}>
                <Text style={styles.workoutModalLabel}>Duration (minutes)</Text>
                <TextInput
                  style={styles.workoutModalInput}
                  value={durationDraft}
                  onChangeText={text => setDurationDraft(text.replace(/[^0-9]/g, ''))}
                  keyboardType="number-pad"
                  inputMode="numeric"
                  accessibilityLabel="Workout duration in minutes"
                  testID="workout-duration-input"
                />
              </View>
              <View style={styles.workoutModalField}>
                <Text style={styles.workoutModalLabel}>Calories burned (estimate)</Text>
                <TextInput
                  style={styles.workoutModalInput}
                  value={caloriesDraft}
                  onChangeText={text => setCaloriesDraft(text.replace(/[^0-9]/g, ''))}
                  keyboardType="number-pad"
                  inputMode="numeric"
                  placeholder="Leave blank if unknown"
                  placeholderTextColor="rgba(255,255,255,0.35)"
                  accessibilityLabel="Workout calories burned estimate"
                  testID="workout-calories-input"
                />
              </View>
              <View style={styles.workoutModalActions}>
                <TouchableOpacity
                  style={styles.workoutModalCancel}
                  onPress={() => setEditingWorkout(null)}
                  disabled={savingWorkout}
                  testID="workout-edit-cancel"
                >
                  <Text style={styles.workoutModalCancelText}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.workoutModalSave, savingWorkout && styles.workoutModalSaveDisabled]}
                  onPress={handleSaveWorkout}
                  disabled={savingWorkout}
                  testID="workout-edit-save"
                >
                  <Text style={styles.workoutModalSaveText}>{savingWorkout ? 'Saving...' : 'Save Workout'}</Text>
                </TouchableOpacity>
              </View>
            </Pressable>
          </KeyboardAvoidingView>
        </Pressable>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  backgroundImage: {
    flex: 1,
    width: '100%',
    height: '100%',
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: 16,
  },
  section: {
    marginBottom: 24,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '700' as const,
    color: '#fff',
    marginBottom: 12,
  },
  editGoalsButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: 'rgba(16, 185, 129, 0.12)',
    borderWidth: 1,
    borderColor: 'rgba(16, 185, 129, 0.35)',
    marginBottom: 12,
  },
  editGoalsText: {
    fontSize: 12,
    fontWeight: '700' as const,
    color: '#10b981',
  },
  progressContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    gap: 12,
  },
  progressRing: {
    alignItems: 'center',
  },
  ringOuter: {
    width: 90,
    height: 90,
    borderRadius: 45,
    backgroundColor: 'rgba(26, 26, 26, 0.8)',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 8,
  },
  ringInner: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#0a0a0a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  ringValue: {
    fontSize: 20,
    fontWeight: '700' as const,
    color: '#fff',
  },
  ringGoal: {
    fontSize: 12,
    color: '#666',
  },
  ringLabel: {
    fontSize: 12,
    color: '#a0a0a0',
    fontWeight: '500' as const,
  },
  startButton: {
    backgroundColor: '#6366f1',
    borderRadius: 16,
    padding: 20,
    shadowColor: '#6366f1',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  startButtonContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  startIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  startTextContainer: {
    flex: 1,
  },
  startButtonTitle: {
    fontSize: 18,
    fontWeight: '700' as const,
    color: '#fff',
    marginBottom: 4,
  },
  startButtonSubtitle: {
    fontSize: 14,
    color: 'rgba(255, 255, 255, 0.8)',
  },
  weekContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: 'rgba(26, 26, 26, 0.8)',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
  },
  dayColumn: {
    alignItems: 'center',
  },
  dayLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 8,
    fontWeight: '600' as const,
  },
  dayCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#1a1a1a',
    borderWidth: 2,
    borderColor: '#333',
    justifyContent: 'center',
    alignItems: 'center',
  },
  dayCircleActive: {
    backgroundColor: '#10b981',
    borderColor: '#10b981',
  },
  dayCheck: {
    fontSize: 16,
    color: '#fff',
    fontWeight: '700' as const,
  },

  trendCard: {
    backgroundColor: 'rgba(26, 26, 26, 0.8)',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
  },
  trendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
  },
  trendLabel: {
    flex: 1,
    fontSize: 14,
    color: '#a0a0a0',
    marginLeft: 12,
  },
  trendValue: {
    fontSize: 18,
    fontWeight: '700' as const,
    color: '#fff',
  },
  awardsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  awardCard: {
    width: '31%',
    aspectRatio: 1,
    borderRadius: 16,
    padding: 12,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
  },
  awardEarned: {
    backgroundColor: 'rgba(245, 158, 11, 0.1)',
    borderColor: 'rgba(245, 158, 11, 0.3)',
  },
  awardLocked: {
    backgroundColor: 'rgba(26, 26, 26, 0.8)',
    borderColor: 'rgba(255, 255, 255, 0.1)',
  },
  awardTitle: {
    fontSize: 11,
    fontWeight: '600' as const,
    color: '#fff',
    textAlign: 'center',
    marginTop: 8,
  },
  awardTitleLocked: {
    color: '#666',
  },
  addWorkoutSection: {
    marginBottom: 20,
  },
  addManualButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(16, 185, 129, 0.15)',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(16, 185, 129, 0.3)',
    gap: 14,
  },
  addManualIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#10b981',
    justifyContent: 'center',
    alignItems: 'center',
  },
  addManualContent: {
    flex: 1,
  },
  addManualTitle: {
    fontSize: 17,
    fontWeight: '600' as const,
    color: '#fff',
    marginBottom: 2,
  },
  addManualSubtitle: {
    fontSize: 13,
    color: '#10b981',
  },
  wearableNote: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginTop: 12,
    paddingHorizontal: 12,
  },
  wearableNoteText: {
    fontSize: 12,
    color: '#6366f1',
    fontStyle: 'italic',
  },
  historyNote: {
    color: 'rgba(255,255,255,0.55)',
    fontSize: 12,
    marginTop: -6,
    marginBottom: 12,
  },
  historyEmpty: {
    color: 'rgba(255,255,255,0.55)',
    fontSize: 14,
    backgroundColor: 'rgba(26,26,26,0.8)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    borderRadius: 14,
    padding: 16,
  },
  workoutHistoryCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 10,
    backgroundColor: 'rgba(26,26,26,0.82)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    borderRadius: 14,
    padding: 12,
    marginBottom: 10,
  },
  workoutHistoryMain: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    flex: 1,
  },
  workoutHistoryIcon: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: 'rgba(16,185,129,0.12)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  workoutHistoryText: {
    flex: 1,
  },
  workoutHistoryTitle: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '700' as const,
    marginBottom: 4,
  },
  workoutHistoryMeta: {
    color: 'rgba(255,255,255,0.55)',
    fontSize: 11,
  },
  workoutHistoryActions: {
    flexDirection: 'row',
    gap: 8,
  },
  historyActionButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(16,185,129,0.1)',
    borderWidth: 1,
    borderColor: 'rgba(16,185,129,0.25)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  historyActionDelete: {
    backgroundColor: 'rgba(239,68,68,0.1)',
    borderColor: 'rgba(239,68,68,0.25)',
  },
  workoutModalBackdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.72)',
  },
  workoutModalKeyboard: {
    width: '100%',
  },
  workoutModalSheet: {
    backgroundColor: 'rgba(20,20,26,0.99)',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    padding: 20,
    paddingBottom: 32,
  },
  workoutModalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  workoutModalTitle: {
    color: '#fff',
    fontSize: 20,
    fontWeight: '700' as const,
  },
  workoutModalClose: {
    color: '#10b981',
    fontSize: 14,
    fontWeight: '600' as const,
    padding: 6,
  },
  workoutModalSubtitle: {
    color: 'rgba(255,255,255,0.55)',
    fontSize: 13,
    marginBottom: 18,
  },
  workoutModalField: {
    marginBottom: 14,
  },
  workoutModalLabel: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 13,
    fontWeight: '600' as const,
    marginBottom: 6,
  },
  workoutModalInput: {
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    color: '#fff',
    fontSize: 16,
  },
  workoutModalActions: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 8,
  },
  workoutModalCancel: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 14,
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
  workoutModalCancelText: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 15,
    fontWeight: '600' as const,
  },
  workoutModalSave: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 14,
    alignItems: 'center',
    backgroundColor: '#10b981',
  },
  workoutModalSaveDisabled: {
    opacity: 0.55,
  },
  workoutModalSaveText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700' as const,
  },
});
