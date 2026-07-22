const { IconButton } = window.AwakenDesignSystem_816712;

function timeLabel(d) {
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/* M3E switch: pill track, thumb grows + shows icon when on */
function M3Switch({ on, onToggle }) {
  return (
    <button
      onClick={(e) => { e.stopPropagation(); onToggle && onToggle(); }}
      aria-label={on ? 'Alarm on' : 'Alarm off'}
      style={{
        width: 56, height: 32, borderRadius: 999, border: on ? '2px solid var(--color-primary)' : '2px solid var(--color-outline)',
        background: on ? 'var(--color-primary)' : 'var(--color-surface-container-high)', cursor: 'pointer', position: 'relative', padding: 0, flex: 'none',
        transition: 'background var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing), border-color var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing)',
      }}
    >
      <span style={{
        position: 'absolute', top: '50%', left: on ? 24 : 4, transform: 'translateY(-50%)',
        width: on ? 24 : 18, height: on ? 24 : 18, borderRadius: 999,
        background: on ? 'var(--color-on-primary)' : 'var(--color-outline)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        transition: 'all var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)',
      }}>
        {on && <span className="material-symbols-outlined" style={{ fontSize: 15, color: 'var(--color-primary)' }}>check</span>}
      </span>
    </button>
  );
}

function AlarmListScreen({ alarms, onDelete, onAdd, onRingNow, onOpenBattery, onOpenSelfTest, onOpenProfile }) {
  const [enabled, setEnabled] = React.useState(() => new Set(alarms.map((a) => a.id)));
  const toggle = (id) => setEnabled((prev) => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n; });
  const n = alarms.length;

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--color-surface)', fontFamily: 'var(--font-sans)' }}>
      {/* M3E large app bar: plain surface, emphasized headline */}
      <div style={{ padding: '18px 20px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <IconButton icon="battery_charging_full" label="Alarm reliability settings" onClick={onOpenBattery} />
          <IconButton icon="bug_report" label="Run alarm reliability self-test" onClick={onOpenSelfTest} />
        </div>
        <button onClick={onOpenProfile} aria-label="Profile"
          style={{ width: 40, height: 40, borderRadius: 999, border: 'none', background: 'var(--color-secondary-container)', color: 'var(--color-on-secondary-container)', fontSize: 15, fontWeight: 600, cursor: 'pointer' }}>G</button>
      </div>
      <div style={{ padding: '4px 20px 14px' }}>
        <div style={{ fontSize: 32, lineHeight: '40px', fontWeight: 700, letterSpacing: '-0.5px', color: 'var(--color-on-surface)' }}>Alarms</div>
        <div style={{ fontSize: 'var(--text-body-medium-size)', color: 'var(--color-on-surface-variant)', marginTop: 2 }}>
          {n === 0 ? 'Nothing scheduled' : `${n} alarm${n === 1 ? '' : 's'} · tap one to preview the wake-up flow`}
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 120px' }}>
        {n === 0 ? (
          <div style={{ textAlign: 'center', marginTop: 56, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 }}>
            <div className="m3x-flower" style={{ width: 108, height: 108, '--flower-color': 'var(--color-secondary-container)' }}>
              <span className="material-symbols-outlined" style={{ fontSize: 44, color: 'var(--color-on-secondary-container)' }}>alarm_add</span>
            </div>
            <div style={{ color: 'var(--color-on-surface)', fontSize: 'var(--text-title-medium-size)', fontWeight: 600 }}>No alarms scheduled</div>
            <div style={{ color: 'var(--color-on-surface-variant)', fontSize: 'var(--text-body-medium-size)', maxWidth: 220 }}>Schedule one and earn tomorrow morning.</div>
          </div>
        ) : (
          /* M3E grouped containers: 3px gaps, outer corners large, inner corners small */
          <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
            {alarms.map((a, i) => {
              const on = enabled.has(a.id);
              const rTop = i === 0 ? 24 : 8;
              const rBot = i === n - 1 ? 24 : 8;
              return (
                <div key={a.id} onClick={() => onRingNow(a)} role="button"
                  style={{
                    borderRadius: `${rTop}px ${rTop}px ${rBot}px ${rBot}px`,
                    background: on ? 'var(--color-primary-container)' : 'var(--color-surface-container-high)',
                    color: on ? 'var(--color-on-primary-container)' : 'var(--color-on-surface-variant)',
                    padding: '18px 18px 16px', cursor: 'pointer',
                    transition: 'background var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing), border-radius var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)',
                    animation: `m3x-rise var(--motion-expressive-default-spatial-duration) var(--motion-expressive-default-spatial-easing) both`,
                    animationDelay: `${i * 60}ms`,
                  }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
                    <div style={{ fontSize: 44, lineHeight: '48px', fontWeight: 700, letterSpacing: '-1px', fontVariantNumeric: 'tabular-nums', color: on ? 'var(--color-on-primary-container)' : 'var(--color-on-surface)' }}>
                      {timeLabel(a.scheduledTime)}
                    </div>
                    <M3Switch on={on} onToggle={() => toggle(a.id)} />
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 10, flexWrap: 'wrap' }}>
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 12px', borderRadius: 999, background: on ? 'rgba(255,255,255,0.55)' : 'var(--color-surface-container)', fontSize: 'var(--text-label-medium-size)', fontWeight: 600, color: on ? 'var(--color-on-primary-container)' : 'var(--color-on-surface-variant)' }}>
                      <span className="material-symbols-outlined" style={{ fontSize: 15 }}>{a.exerciseMode === 'squat' ? 'accessibility_new' : 'sports_gymnastics'}</span>
                      {a.requiredReps} {a.exerciseMode === 'squat' ? 'squats' : 'push-ups'}
                    </span>
                    <span style={{ padding: '5px 12px', borderRadius: 999, background: on ? 'rgba(255,255,255,0.55)' : 'var(--color-surface-container)', fontSize: 'var(--text-label-medium-size)', fontWeight: 600 }}>{a.recurrenceLabel}</span>
                    <span style={{ flex: 1 }} />
                    <button onClick={(e) => { e.stopPropagation(); onDelete(a.id); }} aria-label="Delete alarm"
                      style={{ width: 36, height: 36, borderRadius: 999, border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'inherit' }}>
                      <span className="material-symbols-outlined" style={{ fontSize: 20 }}>delete</span>
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* M3E large FAB — shape-morphs on hover */}
      <div style={{ position: 'absolute', right: 18, bottom: 92 }}>
        <button onClick={onAdd} aria-label="Add alarm" className="m3x-fab"
          style={{
            width: 68, height: 68, borderRadius: 22, border: 'none', background: 'var(--color-primary)', color: 'var(--color-on-primary)',
            boxShadow: 'var(--elevation-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
            transition: 'border-radius var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing), transform var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)',
          }}
          onMouseEnter={(e) => { e.currentTarget.style.borderRadius = '999px'; e.currentTarget.style.transform = 'scale(1.06)'; }}
          onMouseLeave={(e) => { e.currentTarget.style.borderRadius = '22px'; e.currentTarget.style.transform = 'scale(1)'; }}>
          <span className="material-symbols-outlined" style={{ fontSize: 30 }}>add</span>
        </button>
      </div>
    </div>
  );
}

const WEEKDAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const WEEKDAY_LABELS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/* Round stepper button (M3E icon button, tonal) */
function Step({ icon, label, onClick }) {
  return (
    <button onClick={onClick} aria-label={label}
      style={{ width: 44, height: 44, borderRadius: 14, border: 'none', background: 'var(--color-secondary-container)', color: 'var(--color-on-secondary-container)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'border-radius var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)' }}
      onMouseEnter={(e) => { e.currentTarget.style.borderRadius = '999px'; }}
      onMouseLeave={(e) => { e.currentTarget.style.borderRadius = '14px'; }}>
      <span className="material-symbols-outlined" style={{ fontSize: 20 }}>{icon}</span>
    </button>
  );
}

/* Rebuilt as an M3E bottom sheet with a connected button group + day toggles */
function ScheduleDialog({ onCancel, onSchedule }) {
  const [mode, setMode] = React.useState('squat');
  const [reps, setReps] = React.useState(20);
  const [minutes, setMinutes] = React.useState(1);
  const [days, setDays] = React.useState(new Set());

  const toggleDay = (i) => setDays((prev) => {
    const next = new Set(prev);
    next.has(i) ? next.delete(i) : next.add(i);
    return next;
  });

  const modes = [
    { key: 'squat', label: 'Squats', icon: 'accessibility_new' },
    { key: 'pushup', label: 'Push-ups', icon: 'sports_gymnastics' },
  ];

  return (
    <div onClick={onCancel} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.42)', display: 'flex', alignItems: 'flex-end', zIndex: 30 }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        width: '100%', boxSizing: 'border-box', background: 'var(--color-surface-container-low)', borderRadius: '28px 28px 0 0',
        padding: '10px 20px 20px', fontFamily: 'var(--font-sans)',
        animation: 'm3x-rise var(--motion-expressive-default-spatial-duration) var(--motion-expressive-default-spatial-easing) both',
      }}>
        <div style={{ width: 36, height: 4, borderRadius: 999, background: 'var(--color-outline-variant)', margin: '0 auto 14px' }} />
        <div style={{ fontSize: 24, fontWeight: 700, letterSpacing: '-0.3px', color: 'var(--color-on-surface)', marginBottom: 16 }}>Schedule alarm</div>

        {/* connected button group — selected segment morphs to full round */}
        <div style={{ display: 'flex', gap: 3, marginBottom: 16 }}>
          {modes.map((m) => {
            const sel = mode === m.key;
            return (
              <button key={m.key} onClick={() => setMode(m.key)}
                style={{
                  flex: 1, height: 52, border: 'none', cursor: 'pointer',
                  borderRadius: sel ? 999 : 12,
                  background: sel ? 'var(--color-primary)' : 'var(--color-surface-container-high)',
                  color: sel ? 'var(--color-on-primary)' : 'var(--color-on-surface-variant)',
                  fontSize: 'var(--text-label-large-size)', fontWeight: sel ? 700 : 500, fontFamily: 'inherit',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                  transition: 'all var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)',
                }}>
                <span className="material-symbols-outlined" style={{ fontSize: 20 }}>{sel ? 'check' : m.icon}</span>
                {m.label}
              </button>
            );
          })}
        </div>

        {/* steppers in a grouped container */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3, marginBottom: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'var(--color-surface-container-high)', borderRadius: '18px 18px 8px 8px', padding: '10px 14px' }}>
            <span style={{ color: 'var(--color-on-surface)', fontSize: 'var(--text-body-large-size)' }}>Reps</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Step icon="remove" label="Fewer reps" onClick={() => setReps((r) => Math.max(5, r - 5))} />
              <span style={{ minWidth: 44, textAlign: 'center', fontSize: 26, fontWeight: 700, fontVariantNumeric: 'tabular-nums', color: 'var(--color-on-surface)' }}>{reps}</span>
              <Step icon="add" label="More reps" onClick={() => setReps((r) => Math.min(100, r + 5))} />
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'var(--color-surface-container-high)', borderRadius: '8px 8px 18px 18px', padding: '10px 14px' }}>
            <span style={{ color: 'var(--color-on-surface)', fontSize: 'var(--text-body-large-size)' }}>Minutes from now</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Step icon="remove" label="Sooner" onClick={() => setMinutes((m) => Math.max(1, m - 1))} />
              <span style={{ minWidth: 44, textAlign: 'center', fontSize: 26, fontWeight: 700, fontVariantNumeric: 'tabular-nums', color: 'var(--color-on-surface)' }}>{minutes}</span>
              <Step icon="add" label="Later" onClick={() => setMinutes((m) => Math.min(720, m + 1))} />
            </div>
          </div>
        </div>

        <div style={{ fontSize: 'var(--text-label-medium-size)', fontWeight: 600, color: 'var(--color-on-surface-variant)', marginBottom: 8 }}>Repeat</div>
        <div style={{ display: 'flex', gap: 6, marginBottom: 22 }}>
          {WEEKDAYS.map((d, i) => {
            const sel = days.has(i + 1);
            return (
              <button key={i} onClick={() => toggleDay(i + 1)} aria-label={WEEKDAY_LABELS[i]}
                style={{
                  flex: 1, height: 44, border: sel ? 'none' : '1px solid var(--color-outline-variant)', cursor: 'pointer',
                  borderRadius: sel ? 14 : 999,
                  background: sel ? 'var(--color-tertiary-container)' : 'transparent',
                  color: sel ? 'var(--color-on-tertiary-container)' : 'var(--color-on-surface-variant)',
                  fontSize: 'var(--text-label-large-size)', fontWeight: sel ? 700 : 500, fontFamily: 'inherit',
                  transition: 'all var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)',
                }}>{d}</button>
            );
          })}
        </div>

        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={onCancel} style={{ height: 52, padding: '0 20px', borderRadius: 999, border: 'none', background: 'transparent', color: 'var(--color-primary)', fontSize: 'var(--text-label-large-size)', fontWeight: 600, fontFamily: 'inherit', cursor: 'pointer' }}>Cancel</button>
          <button onClick={() => onSchedule({ mode, reps, minutes, days })}
            style={{ flex: 1, height: 52, borderRadius: 999, border: 'none', background: 'var(--color-primary)', color: 'var(--color-on-primary)', fontSize: 'var(--text-label-large-size)', fontWeight: 700, fontFamily: 'inherit', cursor: 'pointer' }}>
            Schedule alarm
          </button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { AlarmListScreen, ScheduleDialog, timeLabel });
