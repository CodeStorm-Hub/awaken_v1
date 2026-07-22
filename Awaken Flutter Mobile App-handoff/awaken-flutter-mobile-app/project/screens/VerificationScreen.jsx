function VerificationScreen({ exerciseMode, targetReps, onComplete, onSkip }) {
  const [phase, setPhase] = React.useState('calibrating'); // calibrating | counting | complete
  const [calibrationLeft, setCalibrationLeft] = React.useState(3);
  const [reps, setReps] = React.useState(0);
  const [bump, setBump] = React.useState(false);

  const doRep = () => {
    if (phase === 'calibrating') {
      setCalibrationLeft((c) => {
        const n = c - 1;
        if (n <= 0) setPhase('counting');
        return Math.max(0, n);
      });
      return;
    }
    if (phase === 'counting') {
      const next = reps + 1;
      setReps(next);
      setBump(true);
      setTimeout(() => setBump(false), 260);
      if (next >= targetReps) setPhase('complete');
    }
  };

  const message = phase === 'calibrating'
    ? `Do ${calibrationLeft} clean rep${calibrationLeft === 1 ? '' : 's'} to calibrate.`
    : phase === 'counting' ? 'Keep going!' : 'Nice work — alarm dismissed.';

  const pct = phase === 'complete' ? 100 : Math.round((reps / targetReps) * 100);
  const label = exerciseMode === 'squat' ? 'squats' : 'push-ups';

  return (
    <div style={{ height: '100%', background: '#0b0d0a', position: 'relative', overflow: 'hidden', fontFamily: 'var(--font-sans)' }}>
      {/* simulated camera feed */}
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 50% 38%, #262a24 0%, #0b0d0a 72%)' }} />

      <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column', padding: 20, boxSizing: 'border-box' }}>
        {/* status banner over live video: black54 scrim per the app's real pattern */}
        <div style={{
          alignSelf: 'center', display: 'flex', alignItems: 'center', gap: 10,
          background: 'rgba(0,0,0,0.54)', backdropFilter: 'blur(6px)', borderRadius: 999, padding: '10px 20px',
          color: '#fff', fontSize: 'var(--text-title-small-size)', fontWeight: 600,
          animation: 'm3x-rise var(--motion-expressive-default-spatial-duration) var(--motion-expressive-default-spatial-easing) both',
        }}>
          {phase !== 'complete' && <span style={{ width: 8, height: 8, borderRadius: 999, background: '#ff5449', animation: 'm3x-pulse 1.2s ease-in-out infinite' }} />}
          {message}
        </div>

        {/* rep segments across the top — one pill per rep */}
        {phase !== 'calibrating' && (
          <div style={{ display: 'flex', gap: 3, marginTop: 14 }}>
            {Array.from({ length: targetReps }).map((_, i) => (
              <div key={i} style={{
                flex: 1, height: 5, borderRadius: 999,
                background: i < reps ? 'var(--color-primary-container)' : 'rgba(255,255,255,0.18)',
                transition: 'background var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing)',
              }} />
            ))}
          </div>
        )}

        <div style={{ flex: 1, cursor: 'pointer' }} onClick={doRep} title="Tap to simulate a rep" />

        {/* contained rep counter: conic ring + huge emphasized numeral */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18, paddingBottom: 10 }} onClick={phase !== 'complete' ? doRep : undefined}>
          <div style={{
            width: 176, height: 176, borderRadius: 999, position: 'relative', flex: 'none',
            background: `conic-gradient(var(--color-primary-container) ${pct * 3.6}deg, rgba(255,255,255,0.14) 0deg)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transform: bump ? 'scale(1.05)' : 'scale(1)',
            transition: 'transform var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)',
          }}>
            <div style={{ width: 152, height: 152, borderRadius: 999, background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(4px)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 0 }}>
              {phase === 'complete' ? (
                <div className="m3x-flower" style={{ width: 84, height: 84, '--flower-color': 'var(--color-primary-container)', animation: 'm3x-pop var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing) both' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: 40, color: 'var(--color-on-primary-container)' }}>check</span>
                </div>
              ) : (
                <React.Fragment>
                  <div style={{ fontSize: 64, lineHeight: '64px', fontWeight: 800, letterSpacing: '-2px', color: '#fff', fontVariantNumeric: 'tabular-nums' }}>{reps}</div>
                  <div style={{ fontSize: 'var(--text-label-large-size)', fontWeight: 600, color: 'rgba(255,255,255,0.75)' }}>of {targetReps} {label}</div>
                </React.Fragment>
              )}
            </div>
          </div>

          {phase === 'complete' ? (
            <button onClick={() => onComplete(reps)}
              style={{ width: '100%', height: 60, borderRadius: 999, border: 'none', cursor: 'pointer', background: 'var(--color-primary-container)', color: 'var(--color-on-primary-container)', fontSize: 17, fontWeight: 700, fontFamily: 'inherit' }}>
              Done
            </button>
          ) : (
            <button onClick={(e) => { e.stopPropagation(); onSkip(reps); }}
              style={{ height: 44, padding: '0 20px', borderRadius: 999, border: '1px solid rgba(255,255,255,0.3)', background: 'transparent', color: 'rgba(255,255,255,0.8)', fontSize: 'var(--text-label-large-size)', fontWeight: 500, fontFamily: 'inherit', cursor: 'pointer' }}>
              I can't do this exercise today
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { VerificationScreen });
