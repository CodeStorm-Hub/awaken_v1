function ReliabilityTestScreen({ onBack }) {
  const [phase, setPhase] = React.useState('idle'); // idle | waiting | passed
  const start = () => {
    setPhase('waiting');
    setTimeout(() => setPhase('passed'), 1800);
  };

  return (
    <div style={{ height: '100%', background: 'var(--color-surface)', fontFamily: 'var(--font-sans)', display: 'flex', flexDirection: 'column', boxSizing: 'border-box' }}>
      <div style={{ padding: '16px 20px 4px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <button onClick={onBack} aria-label="Back"
          style={{ width: 44, height: 44, borderRadius: 999, border: 'none', background: 'var(--color-surface-container-high)', color: 'var(--color-on-surface)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <span className="material-symbols-outlined" style={{ fontSize: 22 }}>arrow_back</span>
        </button>
      </div>
      <div style={{ padding: '8px 20px 0', flex: 1, display: 'flex', flexDirection: 'column', overflowY: 'auto' }}>
        <div style={{ fontSize: 30, lineHeight: '36px', fontWeight: 700, letterSpacing: '-0.4px', color: 'var(--color-on-surface)' }}>Alarm reliability self-test</div>
        <p style={{ margin: '12px 0 0', fontSize: 'var(--text-body-large-size)', lineHeight: 'var(--text-body-large-line)', color: 'var(--color-on-surface-variant)' }}>
          This schedules a test alarm 60 seconds from now, with a 1-rep squat requirement. For a real test of OEM battery killers, start it, then lock your screen and, ideally, swipe Awaken away from the recent-apps list. The alarm should still fire.
        </p>

        {/* status container */}
        <div style={{
          marginTop: 22, borderRadius: 24, padding: '22px 18px', textAlign: 'center',
          background: phase === 'passed' ? 'var(--color-primary-container)' : 'var(--color-surface-container-high)',
          color: phase === 'passed' ? 'var(--color-on-primary-container)' : 'var(--color-on-surface-variant)',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12,
          transition: 'background var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing)',
        }}>
          {phase === 'idle' && (
            <React.Fragment>
              <span className="material-symbols-outlined" style={{ fontSize: 36 }}>bug_report</span>
              <div style={{ fontSize: 'var(--text-title-small-size)', fontWeight: 600 }}>Not started.</div>
            </React.Fragment>
          )}
          {phase === 'waiting' && (
            <React.Fragment>
              <div className="m3x-loader" role="status" aria-label="Waiting for alarm" />
              <div style={{ fontSize: 'var(--text-title-small-size)', fontWeight: 600 }}>Waiting for alarm…</div>
            </React.Fragment>
          )}
          {phase === 'passed' && (
            <React.Fragment>
              <div className="m3x-flower" style={{ width: 72, height: 72, '--flower-color': 'var(--color-primary)', animation: 'm3x-pop var(--motion-expressive-default-spatial-duration) var(--motion-expressive-default-spatial-easing) both' }}>
                <span className="material-symbols-outlined" style={{ fontSize: 34, color: 'var(--color-on-primary)' }}>check</span>
              </div>
              <div style={{ fontSize: 'var(--text-title-medium-size)', fontWeight: 800 }}>PASS — fired 42s after scheduling.</div>
            </React.Fragment>
          )}
        </div>

        <div style={{ flex: 1 }} />
        <div style={{ padding: '16px 0 24px' }}>
          <button onClick={start} disabled={phase === 'waiting'}
            style={{
              width: '100%', height: 56, borderRadius: 999, border: 'none', fontFamily: 'inherit',
              cursor: phase === 'waiting' ? 'default' : 'pointer',
              background: phase === 'waiting' ? 'var(--color-surface-container-high)' : 'var(--color-primary)',
              color: phase === 'waiting' ? 'var(--color-on-surface-variant)' : 'var(--color-on-primary)',
              fontSize: 17, fontWeight: 700,
            }}>
            {phase === 'waiting' ? 'Test running…' : phase === 'passed' ? 'Run again' : 'Start test'}
          </button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ReliabilityTestScreen });
