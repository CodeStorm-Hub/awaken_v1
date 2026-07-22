function BatteryExemptionScreen({ onContinue }) {
  const [status, setStatus] = React.useState(null);
  React.useEffect(() => { const t = setTimeout(() => setStatus({ isExempt: false, isAggressiveOem: true, manufacturer: 'xiaomi' }), 600); return () => clearTimeout(t); }, []);
  const grant = () => setStatus((s) => ({ ...s, isExempt: true }));

  return (
    <div style={{ height: '100%', background: 'var(--color-surface)', fontFamily: 'var(--font-sans)', display: 'flex', flexDirection: 'column', boxSizing: 'border-box' }}>
      <div style={{ padding: '22px 20px 6px' }}>
        <div className="m3x-flower" style={{ width: 64, height: 64, '--flower-color': 'var(--color-secondary-container)', marginBottom: 14 }}>
          <span className="material-symbols-outlined" style={{ fontSize: 30, color: 'var(--color-on-secondary-container)' }}>battery_charging_full</span>
        </div>
        <div style={{ fontSize: 30, lineHeight: '36px', fontWeight: 700, letterSpacing: '-0.4px', color: 'var(--color-on-surface)' }}>Keep alarms reliable</div>
      </div>
      <div style={{ padding: '10px 20px 0', flex: 1, display: 'flex', flexDirection: 'column', overflowY: 'auto' }}>
        <p style={{ margin: 0, fontSize: 'var(--text-body-large-size)', lineHeight: 'var(--text-body-large-line)', color: 'var(--color-on-surface-variant)' }}>
          Android can silently stop apps in the background to save power. If that happens to Awaken, your alarm may not ring. Allowing unrestricted battery usage keeps it reliable.
        </p>

        {!status ? (
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: 36 }}>
            <div className="m3x-loader" role="status" aria-label="Checking battery status" />
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 3, marginTop: 20 }}>
            {/* status container */}
            <div style={{
              display: 'flex', alignItems: 'center', gap: 14, padding: '16px 16px',
              borderRadius: status.isAggressiveOem && !status.isExempt ? '20px 20px 8px 8px' : 20,
              background: status.isExempt ? 'var(--color-primary-container)' : 'var(--color-warning-container)',
              color: status.isExempt ? 'var(--color-on-primary-container)' : '#2a1f00',
              transition: 'background var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing)',
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: 26, flex: 'none' }}>{status.isExempt ? 'check_circle' : 'warning'}</span>
              <div style={{ flex: 1, textAlign: 'left' }}>
                <div style={{ fontSize: 'var(--text-title-small-size)', fontWeight: 700 }}>{status.isExempt ? 'Exemption granted' : 'Still restricted'}</div>
                <div style={{ fontSize: 'var(--text-body-medium-size)', opacity: 0.85 }}>{status.isExempt ? 'Battery optimization exemption granted.' : 'Battery optimization is still restricting Awaken.'}</div>
              </div>
              {!status.isExempt && (
                <button onClick={grant} style={{ height: 40, padding: '0 16px', borderRadius: 999, border: 'none', cursor: 'pointer', background: '#2a1f00', color: 'var(--color-warning-container)', fontSize: 'var(--text-label-large-size)', fontWeight: 700, fontFamily: 'inherit', flex: 'none' }}>Allow</button>
              )}
            </div>

            {status.isAggressiveOem && !status.isExempt && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '16px 16px', borderRadius: '8px 8px 20px 20px', background: 'var(--color-surface-container-high)', color: 'var(--color-on-surface)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: 26, flex: 'none', color: 'var(--color-on-surface-variant)' }}>settings</span>
                <div style={{ flex: 1, textAlign: 'left' }}>
                  <div style={{ fontSize: 'var(--text-title-small-size)', fontWeight: 700 }}>Xiaomi extra step</div>
                  <div style={{ fontSize: 'var(--text-body-medium-size)', color: 'var(--color-on-surface-variant)' }}>Xiaomi devices often need an extra step: allow Awaken to auto-start in the background.</div>
                </div>
                <button style={{ height: 40, padding: '0 14px', borderRadius: 999, border: '1px solid var(--color-outline)', cursor: 'pointer', background: 'transparent', color: 'var(--color-primary)', fontSize: 'var(--text-label-large-size)', fontWeight: 600, fontFamily: 'inherit', flex: 'none' }}>Open</button>
              </div>
            )}
          </div>
        )}

        <div style={{ flex: 1 }} />
        <div style={{ padding: '16px 0 24px' }}>
          <button onClick={onContinue}
            style={{ width: '100%', height: 56, borderRadius: 999, border: 'none', cursor: 'pointer', background: 'var(--color-primary)', color: 'var(--color-on-primary)', fontSize: 17, fontWeight: 700, fontFamily: 'inherit' }}>
            Continue
          </button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { BatteryExemptionScreen });
