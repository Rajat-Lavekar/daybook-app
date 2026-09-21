# Weekly Health design exploration

Status: proposed UI, not an implemented HealthKit extension. Interactive concepts use fictional data and are presented in the conversation.

## References
- Gentler Streak: https://gentlerstories.com/gentlerstreak — clear sleep detail and a restrained wellbeing presentation.
- Athlytic: https://athlyticapp.com/ — glanceable metric hierarchy and distinct sleep, energy and effort areas.
- Apple Training Load: https://support.apple.com/guide/watch/track-your-training-load-apde4c07a6cf/watchos — effort and duration over seven days in longer-term context. Do not copy a proprietary readiness or training-load score.

## Proposed layouts
1. Calendar (recommended): seven weekday workout icons/counts, tap a day for its sessions, durations, active kcal and effort. Sleep and active-energy charts below.
2. Rhythm: aligned seven-day sleep, active-energy and effort charts, with a day detail below. More analytical; separate units/scales, no causal claims.
3. Summary: active/resting energy composition donut with weekly totals, followed by the calendar, sleep and effort. Fits the user's preference for donuts but uses one only for an actual part-to-whole quantity.

All layouts use a selected Monday–Sunday week, previous/next-week controls in the eventual app, local dates, exact date range, refresh time and coverage. Future days and missing readings must be distinct from zero. Current-week comparisons use matched elapsed days; complete weeks compare with complete weeks. A day with no visible workouts is labeled "No workouts recorded", not assumed to be a rest day.

## Data contract for implementation
- Current reader stores daily totals, not workout objects. Add workout UUID, type, start/end, duration, source, active kcal and optional effort; refresh by UUID and handle edits/deletions. Multiple workouts on one day remain individual sessions.
- Read effort with permission using workoutEffortScore and the workout-effort relationship predicate (iOS 18+). Keep estimatedWorkoutEffortScore distinguishable if shown. Missing/denied/unrated values remain unavailable; no substitute zero or fabricated score. Verify the user's Watch ratings on device before claiming parity.
- https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/workouteffortscore
- https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/estimatedworkouteffortscore
- https://developer.apple.com/documentation/healthkit/hkquery/predicateforworkouteffortsamplesrelated(workout:activity:)
- Total energy = active energy + resting (basal) energy. Workout active calories are a subset of daily active energy and must never be added again. Read basalEnergyBurned with separate permission; if unavailable, show active energy only. Energy is an estimate, not a fitness score.
- https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/basalenergyburned
- Sleep duration is based on merged asleep intervals and assigned by wake date. Show observed-night count for averages, nap policy and data gaps. Sleep consistency needs actual onset/wake intervals beyond today's stored summary.
- Per-workout effort is /10 with origin and coverage; a harder effort is not automatically a better week. Do not sum ratings or manufacture a global "performance" grade.
- Keep all data local, and preserve the existing selected-summary export boundary.
