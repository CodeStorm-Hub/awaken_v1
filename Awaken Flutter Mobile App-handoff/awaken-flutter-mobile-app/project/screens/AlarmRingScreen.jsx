function AlarmRingScreen({ exerciseMode, requiredReps, taxMultiplier, onStartWorkout }) {
  const effectiveReps = Math.round(requiredReps * taxMultiplier);
  const [now, setNow] = React.useState(new Date());
  React.useEffect(() => { const t = setInterval(() => setNow(new Date()), 1000); return () => clearInterval(t); }, []);
  const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

  return (
    <div style={{
      height: '100%', background: 'var(--color-error-container)', color: 'var(--color-on-error-container)',
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      padding: '32px 24px', boxSizing: 'border-box', fontFamily: 'var(--font-sans)', textAlign: 'center', position: 'relative', overflow: 'hidden',
    }}>
      {/* current time, quiet, at top */}
      <div style={{ position: 'absolute', top: 28, left: 0, right: 0, fontSize: 'var(--text-title-medium-size)', fontWeight: 600, fontVariantNumeric: 'tabular-nums', opacity: 0.7 }}>{timeStr}</div>

      {/* alarm bell in an expressive flower with radiating rings */}
      <div style={{ position: 'relative', width: 128, height: 128, marginBottom: 28 }}>
        <div style={{ position: 'absolute', inset: 0, borderRadius: 999, border: '3px solid var(--color-error)', animation: 'm3x-ring 1.6s ease-out infinite' }} />
        <div style={{ position: 'absolute', inset: 0, borderRadius: 999, border: '3px solid var(--color-error)', animation: 'm3x-ring 1.6s ease-out .8s infinite' }} />
        <div className="m3x-flower" style={{ position: 'absolute', inset: 0, '--flower-color': 'var(--color-error)' }}>
          <span className="material-symbols-outlined" style={{ fontSize: 52, color: 'var(--color-on-error)', display: 'inline-block', animation: 'm3x-wiggle .5s ease-in-out infinite' }}>alarm</span>
        </div>
      </div>

      <div style={{ fontSize: 30, lineHeight: '36px', fontWeight: 700, letterSpacing: '-0.4px' }}>
        {exerciseMode === 'squat' ? 'Time to squat!' : 'Time to push up!'}
      </div>
      <div style={{ fontSize: 84, lineHeight: '88px', fontWeight: 800, letterSpacing: '-3px', fontVariantNumeric: 'tabular-nums', margin: '10px 0 0' }}>
        {effectiveReps}
      </div>
      <div style={{ fontSize: 'var(--text-title-medium-size)', fontWeight: 600, opacity: 0.85 }}>reps to dismiss</div>

      {taxMultiplier > 1 && (
        /* wake-up tax visualizer — deliberately sharp corners (DS: sharpWarning) */
        <div style={{ marginTop: 18, background: 'var(--color-error)', color: 'var(--color-on-error)', borderRadius: 'var(--radius-sharp-warning)', padding: '8px 16px', fontSize: 'var(--text-label-large-size)', fontWeight: 700 }}>
          Wake-up tax applied (×{taxMultiplier.toFixed(1)})
        </div>
      )}

      <div style={{ position: 'absolute', bottom: 32, left: 24, right: 24 }}>
        <button onClick={() => onStartWorkout(effectiveReps)}
          style={{
            width: '100%', height: 64, borderRadius: 999, border: 'none', cursor: 'pointer',
            background: 'var(--color-on-error-container)', color: 'var(--color-error-container)',
            fontSize: 18, fontWeight: 700, fontFamily: 'inherit', boxShadow: 'var(--elevation-2)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
            transition: 'transform var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing), border-radius var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)',
          }}
          onMouseEnter={(e) => { e.currentTarget.style.transform = 'scale(1.02)'; e.currentTarget.style.borderRadius = '24px'; }}
          onMouseLeave={(e) => { e.currentTarget.style.transform = 'scale(1)'; e.currentTarget.style.borderRadius = '999px'; }}>
          <span className="material-symbols-outlined" style={{ fontSize: 24 }}>videocam</span>
          Start workout to dismiss
        </button>
      </div>
    </div>
  );
}

Object.assign(window, { AlarmRingScreen });
