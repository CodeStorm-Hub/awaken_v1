function CelebrationSheet({ exerciseMode, repsCompleted, streak, onDone }) {
  const noun = exerciseMode === 'squat' ? 'squats' : 'push-ups';
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.42)', display: 'flex', alignItems: 'flex-end', zIndex: 20 }}>
      <div style={{
        width: '100%', background: 'var(--color-surface-container-low)', borderRadius: '28px 28px 0 0',
        padding: '12px 24px 24px', boxSizing: 'border-box', textAlign: 'center', fontFamily: 'var(--font-sans)',
        animation: 'm3x-rise var(--motion-expressive-default-spatial-duration) var(--motion-expressive-default-spatial-easing) both',
      }}>
        <div style={{ width: 36, height: 4, borderRadius: 999, background: 'var(--color-outline-variant)', margin: '0 auto 20px' }} />

        {/* trophy in expressive flower shape — spatial spring pop */}
        <div className="m3x-flower" style={{ width: 116, height: 116, margin: '0 auto', '--flower-color': 'var(--color-primary-container)', animation: 'm3x-pop var(--motion-expressive-default-spatial-duration) var(--motion-expressive-default-spatial-easing) both' }}>
          <span className="material-symbols-outlined" style={{ fontSize: 52, color: 'var(--color-on-primary-container)' }}>emoji_events</span>
        </div>

        <div style={{ fontSize: 28, lineHeight: '34px', fontWeight: 700, letterSpacing: '-0.4px', color: 'var(--color-on-surface)', marginTop: 18 }}>Alarm dismissed!</div>
        <div style={{ fontSize: 'var(--text-body-large-size)', color: 'var(--color-on-surface-variant)', marginTop: 6 }}>Nice work — that's how mornings are won.</div>

        {/* stat chips in a connected group */}
        <div style={{ display: 'flex', gap: 3, margin: '20px 0 22px' }}>
          <div style={{ flex: 1, background: 'var(--color-secondary-container)', color: 'var(--color-on-secondary-container)', borderRadius: '20px 8px 8px 20px', padding: '14px 8px' }}>
            <div style={{ fontSize: 30, fontWeight: 800, letterSpacing: '-1px', fontVariantNumeric: 'tabular-nums' }}>{repsCompleted}</div>
            <div style={{ fontSize: 'var(--text-label-medium-size)', fontWeight: 600 }}>{noun} completed</div>
          </div>
          <div style={{ flex: 1, background: 'var(--color-tertiary-container)', color: 'var(--color-on-tertiary-container)', borderRadius: '8px 20px 20px 8px', padding: '14px 8px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4 }}>
              <span className="material-symbols-outlined" style={{ fontSize: 24 }}>local_fire_department</span>
              <span style={{ fontSize: 30, fontWeight: 800, letterSpacing: '-1px', fontVariantNumeric: 'tabular-nums' }}>{streak}</span>
            </div>
            <div style={{ fontSize: 'var(--text-label-medium-size)', fontWeight: 600 }}>day streak</div>
          </div>
        </div>

        <button onClick={onDone}
          style={{ width: '100%', height: 56, borderRadius: 999, border: 'none', cursor: 'pointer', background: 'var(--color-primary)', color: 'var(--color-on-primary)', fontSize: 17, fontWeight: 700, fontFamily: 'inherit' }}>
          Nice!
        </button>
      </div>
    </div>
  );
}

Object.assign(window, { CelebrationSheet });
