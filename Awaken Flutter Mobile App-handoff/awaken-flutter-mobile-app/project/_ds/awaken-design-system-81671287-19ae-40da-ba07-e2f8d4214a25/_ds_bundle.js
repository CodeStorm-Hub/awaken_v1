/* @ds-bundle: {"format":4,"namespace":"AwakenDesignSystem_816712","components":[{"name":"Card","sourcePath":"components/data-display/Card.jsx"},{"name":"ListItem","sourcePath":"components/data-display/ListItem.jsx"},{"name":"RepCounter","sourcePath":"components/data-display/RepCounter.jsx"},{"name":"Badge","sourcePath":"components/feedback/Badge.jsx"},{"name":"ProgressSpinner","sourcePath":"components/feedback/ProgressSpinner.jsx"},{"name":"StatusBanner","sourcePath":"components/feedback/StatusBanner.jsx"},{"name":"Button","sourcePath":"components/forms/Button.jsx"},{"name":"Chip","sourcePath":"components/forms/Chip.jsx"},{"name":"IconButton","sourcePath":"components/forms/IconButton.jsx"},{"name":"Dialog","sourcePath":"components/overlays/Dialog.jsx"}],"sourceHashes":{"components/data-display/Card.jsx":"0b492b0cd77f","components/data-display/ListItem.jsx":"d2e3845437f1","components/data-display/RepCounter.jsx":"3e2ecd7798e1","components/feedback/Badge.jsx":"a5b2f90e4d27","components/feedback/ProgressSpinner.jsx":"6a5db43a9741","components/feedback/StatusBanner.jsx":"9cbee4c14062","components/forms/Button.jsx":"80d3ab444d4d","components/forms/Chip.jsx":"0675b892c838","components/forms/IconButton.jsx":"461de2d71409","components/overlays/Dialog.jsx":"ee871f0f6268","ui_kits/awaken-app/AlarmListScreen.jsx":"c9ada37c61f5","ui_kits/awaken-app/AlarmRingScreen.jsx":"78177ca2c1bc","ui_kits/awaken-app/BatteryExemptionScreen.jsx":"6d38809eac1c","ui_kits/awaken-app/CelebrationSheet.jsx":"8c08854fb37f","ui_kits/awaken-app/ReliabilityTestScreen.jsx":"9df6946290f2","ui_kits/awaken-app/VerificationScreen.jsx":"3b03ad9b815e","ui_kits/awaken-app/android-frame.jsx":"cbf1bf9e56aa"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.AwakenDesignSystem_816712 = window.AwakenDesignSystem_816712 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/data-display/Card.jsx
try { (() => {
function Card({
  children,
  sharp = false,
  elevation = 1,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--color-surface-container-low)',
      borderRadius: sharp ? 'var(--radius-sharp-warning)' : 'var(--radius-lg)',
      boxShadow: `var(--elevation-${elevation})`,
      padding: 'var(--space-4)',
      boxSizing: 'border-box',
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data-display/Card.jsx", error: String((e && e.message) || e) }); }

// components/data-display/ListItem.jsx
try { (() => {
function ListItem({
  title,
  subtitle,
  trailing,
  onClick
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 12,
      padding: '12px 16px',
      borderBottom: '1px solid var(--color-outline-variant)',
      cursor: onClick ? 'pointer' : 'default'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-title-medium-size)',
      fontWeight: 'var(--text-title-medium-weight)',
      color: 'var(--color-on-surface)'
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-body-medium-size)',
      color: 'var(--color-on-surface-variant)',
      marginTop: 2
    }
  }, subtitle)), trailing);
}
Object.assign(__ds_scope, { ListItem });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data-display/ListItem.jsx", error: String((e && e.message) || e) }); }

// components/data-display/RepCounter.jsx
try { (() => {
function RepCounter({
  current,
  target,
  label,
  tone = 'light'
}) {
  const fg = tone === 'onDark' ? '#fff' : 'var(--color-on-surface)';
  const sub = tone === 'onDark' ? 'rgba(255,255,255,0.7)' : 'var(--color-on-surface-variant)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      fontFamily: 'var(--font-sans)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-display-large-size)',
      lineHeight: 'var(--text-display-large-line)',
      fontWeight: 700,
      color: fg
    }
  }, current, target != null ? ` / ${target}` : ''), label && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-title-medium-size)',
      color: sub,
      marginTop: 4
    }
  }, label));
}
Object.assign(__ds_scope, { RepCounter });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data-display/RepCounter.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Badge.jsx
try { (() => {
function Badge({
  icon,
  children,
  tone = 'primary'
}) {
  const map = {
    primary: {
      bg: 'var(--color-primary-container)',
      fg: 'var(--color-on-primary-container)'
    },
    success: {
      bg: 'var(--color-primary-container)',
      fg: 'var(--color-on-primary-container)'
    },
    warning: {
      bg: 'var(--color-warning-container)',
      fg: '#3d2900'
    },
    error: {
      bg: 'var(--color-error-container)',
      fg: 'var(--color-on-error-container)'
    }
  };
  const c = map[tone] || map.primary;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-label-large-size)',
      fontWeight: 'var(--text-label-large-weight)',
      background: c.bg,
      color: c.fg,
      padding: '6px 12px',
      borderRadius: 'var(--radius-xxl)'
    }
  }, icon && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-outlined",
    style: {
      fontSize: 16
    }
  }, icon), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Badge.jsx", error: String((e && e.message) || e) }); }

// components/feedback/ProgressSpinner.jsx
try { (() => {
function ProgressSpinner({
  size = 40,
  tone = 'primary'
}) {
  const color = tone === 'onDark' ? '#fff' : 'var(--color-primary)';
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-block',
      width: size,
      height: size,
      border: `${Math.max(3, size / 10)}px solid ${tone === 'onDark' ? 'rgba(255,255,255,0.25)' : 'var(--color-surface-variant)'}`,
      borderTopColor: color,
      borderRadius: '50%',
      animation: 'awaken-spin 900ms linear infinite'
    }
  }), /*#__PURE__*/React.createElement("style", null, '@keyframes awaken-spin{to{transform:rotate(360deg)}}'));
}
Object.assign(__ds_scope, { ProgressSpinner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/ProgressSpinner.jsx", error: String((e && e.message) || e) }); }

// components/feedback/StatusBanner.jsx
try { (() => {
function StatusBanner({
  children,
  tone = 'onDark'
}) {
  const dark = tone === 'onDark';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-body-medium-size)',
      lineHeight: 'var(--text-body-medium-line)',
      color: dark ? '#fff' : 'var(--color-on-surface)',
      background: dark ? 'rgba(0,0,0,0.33)' : 'var(--color-surface-container)',
      padding: '12px 16px',
      borderRadius: 'var(--radius-lg)',
      textAlign: 'center'
    }
  }, children);
}
Object.assign(__ds_scope, { StatusBanner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/StatusBanner.jsx", error: String((e && e.message) || e) }); }

// components/forms/Button.jsx
try { (() => {
const VARIANTS = {
  filled: {
    background: 'var(--color-primary)',
    color: 'var(--color-on-primary)',
    border: 'none'
  },
  tonal: {
    background: 'var(--color-secondary-container)',
    color: 'var(--color-on-secondary-container)',
    border: 'none'
  },
  outlined: {
    background: 'transparent',
    color: 'var(--color-on-surface)',
    border: '1px solid var(--color-outline)'
  },
  text: {
    background: 'transparent',
    color: 'var(--color-primary)',
    border: 'none'
  }
};
function Button({
  children,
  variant = 'filled',
  disabled = false,
  onClick,
  style
}) {
  const v = VARIANTS[variant] || VARIANTS.filled;
  return /*#__PURE__*/React.createElement("button", {
    onClick: disabled ? undefined : onClick,
    disabled: disabled,
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-label-large-size)',
      fontWeight: 'var(--text-label-large-weight)',
      letterSpacing: 'var(--text-label-large-tracking)',
      padding: '10px 24px',
      borderRadius: 'var(--radius-xxl)',
      cursor: disabled ? 'default' : 'pointer',
      opacity: disabled ? 0.38 : 1,
      transition: `background-color var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing)`,
      ...v,
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Button.jsx", error: String((e && e.message) || e) }); }

// components/forms/Chip.jsx
try { (() => {
function Chip({
  children,
  selected = false,
  onClick
}) {
  return /*#__PURE__*/React.createElement("button", {
    onClick: onClick,
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-label-large-size)',
      fontWeight: 'var(--text-label-large-weight)',
      padding: '6px 14px',
      borderRadius: 'var(--radius-sm)',
      border: selected ? '1px solid transparent' : '1px solid var(--color-outline)',
      background: selected ? 'var(--color-secondary-container)' : 'transparent',
      color: selected ? 'var(--color-on-secondary-container)' : 'var(--color-on-surface-variant)',
      cursor: 'pointer',
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      transition: `background-color var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing)`
    }
  }, selected && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-outlined",
    style: {
      fontSize: 16
    }
  }, "check"), children);
}
Object.assign(__ds_scope, { Chip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Chip.jsx", error: String((e && e.message) || e) }); }

// components/forms/IconButton.jsx
try { (() => {
function IconButton({
  icon,
  label,
  tone = 'default',
  onClick,
  size = 24
}) {
  const toneColor = tone === 'error' ? 'var(--color-error)' : tone === 'onDark' ? '#fff' : 'var(--color-on-surface-variant)';
  return /*#__PURE__*/React.createElement("button", {
    onClick: onClick,
    "aria-label": label,
    title: label,
    style: {
      width: size + 24,
      height: size + 24,
      borderRadius: '50%',
      border: 'none',
      background: 'transparent',
      color: toneColor,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      cursor: 'pointer',
      transition: `background-color var(--motion-expressive-fast-effects-duration) var(--motion-expressive-fast-effects-easing)`
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-outlined",
    style: {
      fontSize: size
    }
  }, icon));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/overlays/Dialog.jsx
try { (() => {
function Dialog({
  title,
  children,
  actions,
  open = true
}) {
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'fixed',
      inset: 0,
      background: 'rgba(0,0,0,0.4)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--color-surface-container-high)',
      borderRadius: 'var(--radius-xl)',
      padding: 'var(--space-6)',
      minWidth: 300,
      maxWidth: 400,
      boxShadow: 'var(--elevation-3)',
      fontFamily: 'var(--font-sans)'
    }
  }, title && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-headline-small-size)',
      lineHeight: 'var(--text-headline-small-line)',
      color: 'var(--color-on-surface)',
      marginBottom: 16
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--color-on-surface-variant)',
      fontSize: 'var(--text-body-medium-size)'
    }
  }, children), actions && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'flex-end',
      gap: 8,
      marginTop: 24
    }
  }, actions)));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/overlays/Dialog.jsx", error: String((e && e.message) || e) }); }

// ui_kits/awaken-app/AlarmListScreen.jsx
try { (() => {
const {
  Button,
  IconButton,
  Chip,
  ListItem,
  Dialog
} = window.AwakenDesignSystem_816712;
function timeLabel(d) {
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
function AlarmListScreen({
  alarms,
  onDelete,
  onAdd,
  onRingNow,
  onOpenBattery,
  onOpenSelfTest
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      background: 'var(--color-surface)',
      fontFamily: 'var(--font-sans)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '12px 8px 12px 20px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-title-large-size)',
      fontWeight: 'var(--text-title-large-weight)',
      color: 'var(--color-on-surface)'
    }
  }, "Awaken"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    icon: "battery_charging_full",
    label: "Alarm reliability settings",
    onClick: onOpenBattery
  }), /*#__PURE__*/React.createElement(IconButton, {
    icon: "bug_report",
    label: "Run alarm reliability self-test",
    onClick: onOpenSelfTest
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto'
    }
  }, alarms.length === 0 ? /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      color: 'var(--color-on-surface-variant)',
      marginTop: 48
    }
  }, "No alarms scheduled.") : alarms.map(a => /*#__PURE__*/React.createElement(ListItem, {
    key: a.id,
    title: timeLabel(a.scheduledTime),
    subtitle: `${a.exerciseMode} · ${a.requiredReps} reps · ${a.recurrenceLabel}`,
    trailing: /*#__PURE__*/React.createElement(IconButton, {
      icon: "delete",
      label: "Delete",
      tone: "error",
      onClick: () => onDelete(a.id)
    }),
    onClick: () => onRingNow(a)
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      right: 20,
      bottom: 24
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onAdd,
    "aria-label": "Add alarm",
    style: {
      width: 56,
      height: 56,
      borderRadius: 'var(--radius-lg)',
      border: 'none',
      background: 'var(--color-primary-container)',
      color: 'var(--color-on-primary-container)',
      boxShadow: 'var(--elevation-2)',
      cursor: 'pointer',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-outlined",
    style: {
      fontSize: 28
    }
  }, "add"))));
}
const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
function ScheduleDialog({
  onCancel,
  onSchedule
}) {
  const [mode, setMode] = React.useState('squat');
  const [reps, setReps] = React.useState(20);
  const [minutes, setMinutes] = React.useState(1);
  const [days, setDays] = React.useState(new Set());
  const toggleDay = i => setDays(prev => {
    const next = new Set(prev);
    next.has(i) ? next.delete(i) : next.add(i);
    return next;
  });
  return /*#__PURE__*/React.createElement(Dialog, {
    title: "Schedule alarm",
    actions: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
      variant: "text",
      onClick: onCancel
    }, "Cancel"), /*#__PURE__*/React.createElement(Button, {
      variant: "filled",
      onClick: () => onSchedule({
        mode,
        reps,
        minutes,
        days
      })
    }, "Schedule"))
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      marginBottom: 16
    }
  }, ['squat', 'pushup'].map(m => /*#__PURE__*/React.createElement(Chip, {
    key: m,
    selected: mode === m,
    onClick: () => setMode(m)
  }, m === 'squat' ? 'Squat' : 'Push-up'))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement("span", null, "Reps"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    icon: "remove",
    label: "Fewer reps",
    onClick: () => setReps(r => Math.max(5, r - 5)),
    size: 18
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      minWidth: 24,
      textAlign: 'center'
    }
  }, reps), /*#__PURE__*/React.createElement(IconButton, {
    icon: "add",
    label: "More reps",
    onClick: () => setReps(r => Math.min(100, r + 5)),
    size: 18
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginBottom: 16
    }
  }, /*#__PURE__*/React.createElement("span", null, "Minutes from now"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    icon: "remove",
    label: "Sooner",
    onClick: () => setMinutes(m => Math.max(1, m - 1)),
    size: 18
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      minWidth: 24,
      textAlign: 'center'
    }
  }, minutes), /*#__PURE__*/React.createElement(IconButton, {
    icon: "add",
    label: "Later",
    onClick: () => setMinutes(m => Math.min(720, m + 1)),
    size: 18
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-label-medium-size)',
      color: 'var(--color-on-surface-variant)',
      marginBottom: 6
    }
  }, "Repeat"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 4,
      flexWrap: 'wrap'
    }
  }, WEEKDAYS.map((d, i) => /*#__PURE__*/React.createElement(Chip, {
    key: d,
    selected: days.has(i + 1),
    onClick: () => toggleDay(i + 1)
  }, d))));
}
Object.assign(window, {
  AlarmListScreen,
  ScheduleDialog,
  timeLabel
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/awaken-app/AlarmListScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/awaken-app/AlarmRingScreen.jsx
try { (() => {
const {
  Button,
  Card
} = window.AwakenDesignSystem_816712;
function AlarmRingScreen({
  exerciseMode,
  requiredReps,
  taxMultiplier,
  onStartWorkout
}) {
  const effectiveReps = Math.round(requiredReps * taxMultiplier);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      background: 'var(--color-error-container)',
      color: 'var(--color-on-error-container)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 24,
      boxSizing: 'border-box',
      fontFamily: 'var(--font-sans)',
      textAlign: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-headline-medium-size)',
      lineHeight: 'var(--text-headline-medium-line)'
    }
  }, exerciseMode === 'squat' ? 'Time to squat!' : 'Time to push up!'), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-display-large-size)',
      lineHeight: 'var(--text-display-large-line)',
      fontWeight: 700,
      margin: '8px 0'
    }
  }, effectiveReps, " reps"), taxMultiplier > 1 && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-body-medium-size)'
    }
  }, "Wake-up tax applied (\xD7", taxMultiplier.toFixed(1), ")"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 32
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "filled",
    onClick: () => onStartWorkout(effectiveReps),
    style: {
      padding: '16px 32px'
    }
  }, "Start Workout to Dismiss")));
}
Object.assign(window, {
  AlarmRingScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/awaken-app/AlarmRingScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/awaken-app/BatteryExemptionScreen.jsx
try { (() => {
const {
  Button,
  ProgressSpinner
} = window.AwakenDesignSystem_816712;
function BatteryExemptionScreen({
  onContinue
}) {
  const [status, setStatus] = React.useState(null);
  React.useEffect(() => {
    const t = setTimeout(() => setStatus({
      isExempt: false,
      isAggressiveOem: true,
      manufacturer: 'xiaomi'
    }), 500);
    return () => clearTimeout(t);
  }, []);
  const grant = () => setStatus(s => ({
    ...s,
    isExempt: true
  }));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      background: 'var(--color-surface)',
      fontFamily: 'var(--font-sans)',
      display: 'flex',
      flexDirection: 'column',
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 20px',
      fontSize: 'var(--text-title-large-size)',
      fontWeight: 'var(--text-title-large-weight)',
      color: 'var(--color-on-surface)'
    }
  }, "Keep alarms reliable"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 24px',
      flex: 1,
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--text-body-large-size)',
      lineHeight: 'var(--text-body-large-line)',
      color: 'var(--color-on-surface)'
    }
  }, "Android can silently stop apps in the background to save power. If that happens to Awaken, your alarm may not ring. Allowing unrestricted battery usage keeps it reliable."), !status ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center',
      marginTop: 24
    }
  }, /*#__PURE__*/React.createElement(ProgressSpinner, null)) : /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginTop: 16
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-outlined",
    style: {
      color: status.isExempt ? 'var(--color-primary)' : 'var(--color-warning)'
    }
  }, status.isExempt ? 'check_circle' : 'warning'), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-on-surface)'
    }
  }, status.isExempt ? 'Battery optimization exemption granted.' : 'Battery optimization is still restricting Awaken.')), !status.isExempt && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "filled",
    onClick: grant
  }, "Allow unrestricted battery usage")), status.isAggressiveOem && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--text-body-medium-size)',
      color: 'var(--color-on-surface)'
    }
  }, "Xiaomi devices often need an extra step: allow Awaken to auto-start in the background."), /*#__PURE__*/React.createElement(Button, {
    variant: "outlined"
  }, "Open Xiaomi settings"))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      paddingBottom: 24
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "tonal",
    onClick: onContinue
  }, "Continue"))));
}
Object.assign(window, {
  BatteryExemptionScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/awaken-app/BatteryExemptionScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/awaken-app/CelebrationSheet.jsx
try { (() => {
const {
  Button
} = window.AwakenDesignSystem_816712;
function CelebrationSheet({
  exerciseMode,
  repsCompleted,
  streak,
  onDone
}) {
  const [scale, setScale] = React.useState(0);
  React.useEffect(() => {
    const t = setTimeout(() => setScale(1), 20);
    return () => clearTimeout(t);
  }, []);
  const noun = exerciseMode === 'squat' ? 'squats' : 'push-ups';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'rgba(0,0,0,0.4)',
      display: 'flex',
      alignItems: 'flex-end'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: '100%',
      background: 'var(--color-surface-container-high)',
      borderTopLeftRadius: 'var(--radius-xl)',
      borderTopRightRadius: 'var(--radius-xl)',
      padding: '32px 24px 24px',
      boxSizing: 'border-box',
      textAlign: 'center',
      fontFamily: 'var(--font-sans)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-outlined",
    style: {
      fontSize: 64,
      color: 'var(--color-primary)',
      display: 'inline-block',
      transform: `scale(${scale})`,
      transition: `transform var(--motion-expressive-fast-spatial-duration) var(--motion-expressive-fast-spatial-easing)`
    }
  }, "emoji_events"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-headline-small-size)',
      color: 'var(--color-on-surface)',
      marginTop: 16
    }
  }, "Alarm dismissed!"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-body-large-size)',
      color: 'var(--color-on-surface-variant)',
      marginTop: 8
    }
  }, repsCompleted, " ", noun, " completed"), streak > 1 && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-title-medium-size)',
      color: 'var(--color-on-surface)',
      marginTop: 16
    }
  }, streak, "-day streak"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 24
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "filled",
    onClick: onDone
  }, "Nice!"))));
}
Object.assign(window, {
  CelebrationSheet
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/awaken-app/CelebrationSheet.jsx", error: String((e && e.message) || e) }); }

// ui_kits/awaken-app/ReliabilityTestScreen.jsx
try { (() => {
const {
  Button,
  Badge
} = window.AwakenDesignSystem_816712;
function ReliabilityTestScreen({
  onBack
}) {
  const [phase, setPhase] = React.useState('idle'); // idle | waiting | passed
  const start = () => {
    setPhase('waiting');
    setTimeout(() => setPhase('passed'), 1800);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      background: 'var(--color-surface)',
      fontFamily: 'var(--font-sans)',
      display: 'flex',
      flexDirection: 'column',
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 20px',
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-outlined",
    style: {
      cursor: 'pointer',
      color: 'var(--color-on-surface)'
    },
    onClick: onBack
  }, "arrow_back"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-title-large-size)',
      fontWeight: 'var(--text-title-large-weight)',
      color: 'var(--color-on-surface)'
    }
  }, "Alarm reliability self-test")), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 24px',
      flex: 1,
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--text-body-large-size)',
      lineHeight: 'var(--text-body-large-line)',
      color: 'var(--color-on-surface)'
    }
  }, "This schedules a test alarm 60 seconds from now, with a 1-rep squat requirement. For a real test of OEM battery killers, start it, then lock your screen and, ideally, swipe Awaken away from the recent-apps list. The alarm should still fire."), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16
    }
  }, phase === 'idle' && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-on-surface-variant)'
    }
  }, "Not started."), phase === 'waiting' && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-on-surface-variant)'
    }
  }, "Waiting for alarm\u2026"), phase === 'passed' && /*#__PURE__*/React.createElement(Badge, {
    icon: "check_circle",
    tone: "success"
  }, "PASS \u2014 fired 42s after scheduling.")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      paddingBottom: 24
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "filled",
    disabled: phase === 'waiting',
    onClick: start
  }, phase === 'waiting' ? 'Test running…' : 'Start test'))));
}
Object.assign(window, {
  ReliabilityTestScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/awaken-app/ReliabilityTestScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/awaken-app/VerificationScreen.jsx
try { (() => {
const {
  StatusBanner,
  RepCounter,
  Button
} = window.AwakenDesignSystem_816712;
function VerificationScreen({
  exerciseMode,
  targetReps,
  onComplete,
  onSkip
}) {
  const [phase, setPhase] = React.useState('calibrating'); // calibrating | counting | complete
  const [calibrationLeft, setCalibrationLeft] = React.useState(3);
  const [reps, setReps] = React.useState(0);
  const doRep = () => {
    if (phase === 'calibrating') {
      if (calibrationLeft > 1) {
        setCalibrationLeft(c => c - 1);
      } else {
        setPhase('counting');
      }
      return;
    }
    if (phase === 'counting') {
      const next = reps + 1;
      setReps(next);
      if (next >= targetReps) setPhase('complete');
    }
  };
  const message = phase === 'calibrating' ? `Do ${calibrationLeft} clean rep${calibrationLeft === 1 ? '' : 's'} to calibrate.` : phase === 'counting' ? 'Keep going!' : 'Nice work — alarm dismissed.';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      background: '#111',
      position: 'relative',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'radial-gradient(circle at 50% 40%, #2a2a2a 0%, #0a0a0a 70%)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      padding: 24,
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement(StatusBanner, null, message), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      cursor: 'pointer'
    },
    onClick: doRep,
    title: "Tap to simulate a rep"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      paddingBottom: 8
    }
  }, /*#__PURE__*/React.createElement(RepCounter, {
    current: reps,
    target: targetReps,
    label: exerciseMode === 'squat' ? 'Squats' : 'Push-ups',
    tone: "onDark"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center',
      marginTop: 24
    }
  }, phase === 'complete' ? /*#__PURE__*/React.createElement(Button, {
    variant: "filled",
    onClick: () => onComplete(reps)
  }, "Done") : /*#__PURE__*/React.createElement(Button, {
    variant: "text",
    onClick: () => onSkip(reps),
    style: {
      color: 'rgba(255,255,255,0.7)'
    }
  }, "I can't do this exercise today")))));
}
Object.assign(window, {
  VerificationScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/awaken-app/VerificationScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/awaken-app/android-frame.jsx
try { (() => {
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)
// Copied omelette starter. Re-running copy_starter_component with this kind overwrites this file with the latest version (page content is unaffected).

/* BEGIN USAGE */
// Android.jsx — Simplified Android (Material 3) device frame
// Status bar + top app bar + content + gesture nav + keyboard.
// Based on Figma M3 spec. No dependencies, no image assets.
// Exports (to window): AndroidDevice, AndroidStatusBar, AndroidAppBar, AndroidListItem, AndroidNavBar, AndroidKeyboard
//
// Usage — wrap your screen content in <AndroidDevice> to get the bezel, status
// bar and gesture nav (props: title, large, keyboard, dark):
//
//   <AndroidDevice title="Inbox" large>
//     ...your screen content...
//   </AndroidDevice>
//   <AndroidDevice title="Compose" keyboard>…</AndroidDevice>
/* END USAGE */

const MD_C = {
  surface: '#f4fbf8',
  surfaceVariant: '#dae5e1',
  inverseOnSurface: '#ecf2ef',
  secondaryContainer: '#cde8e1',
  primaryFixedDim: '#83d5c6',
  onSurface: '#171d1b',
  onSurfaceVar: '#49454f',
  onPrimaryContainer: '#00201c',
  primary: '#006a60',
  frameBorder: 'rgba(116,119,117,0.5)'
};

// ─────────────────────────────────────────────────────────────
// Status bar (time left, wifi/cell/battery right)
// ─────────────────────────────────────────────────────────────
function AndroidStatusBar({
  dark = false
}) {
  const c = dark ? '#fff' : MD_C.onSurface;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 40,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 16px',
      position: 'relative',
      fontFamily: 'Roboto, system-ui, sans-serif'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 128,
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 14,
      fontWeight: 400,
      letterSpacing: 0.25,
      lineHeight: '20px',
      color: c
    }
  }, "9:30")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: '50%',
      top: 8,
      transform: 'translateX(-50%)',
      width: 24,
      height: 24,
      borderRadius: 100,
      background: '#2e2e2e'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      paddingRight: 2
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 16 16",
    style: {
      marginRight: -2
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M8 13.3L.67 5.97a10.37 10.37 0 0114.66 0L8 13.3z",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 16 16",
    style: {
      marginRight: -2
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M14.67 14.67V1.33L1.33 14.67h13.34z",
    fill: c
  }))), /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 16 16"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "3.75",
    y: "2",
    width: "8.5",
    height: "13",
    rx: "1.5",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "5.5",
    y: "0.9",
    width: "5",
    height: "2",
    rx: "0.5",
    fill: c
  }))));
}

// ─────────────────────────────────────────────────────────────
// Top app bar (Material 3 small/medium)
// ─────────────────────────────────────────────────────────────
function AndroidAppBar({
  title = 'Title',
  large = false
}) {
  const iconDot = /*#__PURE__*/React.createElement("div", {
    style: {
      width: 48,
      height: 48,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 22,
      height: 22,
      borderRadius: '50%',
      background: MD_C.onSurfaceVar,
      opacity: 0.3
    }
  }));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: MD_C.surface,
      padding: '4px 4px 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 56,
      display: 'flex',
      alignItems: 'center',
      gap: 4
    }
  }, iconDot, !large && /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      fontSize: 22,
      fontWeight: 400,
      color: MD_C.onSurface,
      fontFamily: 'Roboto, system-ui, sans-serif'
    }
  }, title), large && /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), iconDot), large && /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 16px 20px',
      fontSize: 28,
      fontWeight: 400,
      color: MD_C.onSurface,
      fontFamily: 'Roboto, system-ui, sans-serif'
    }
  }, title));
}

// ─────────────────────────────────────────────────────────────
// List item (Material 3)
// ─────────────────────────────────────────────────────────────
function AndroidListItem({
  headline,
  supporting,
  leading
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 16,
      padding: '12px 16px',
      minHeight: 56,
      boxSizing: 'border-box',
      fontFamily: 'Roboto, system-ui, sans-serif'
    }
  }, leading && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 40,
      borderRadius: '50%',
      background: MD_C.primary,
      color: '#fff',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: 18,
      fontWeight: 500,
      flexShrink: 0
    }
  }, leading), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      color: MD_C.onSurface,
      lineHeight: '24px'
    }
  }, headline), supporting && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: MD_C.onSurfaceVar,
      lineHeight: '20px'
    }
  }, supporting)));
}

// ─────────────────────────────────────────────────────────────
// Gesture nav bar (pill)
// ─────────────────────────────────────────────────────────────
function AndroidNavBar({
  dark = false
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 108,
      height: 4,
      borderRadius: 2,
      background: dark ? '#fff' : MD_C.onSurface,
      opacity: 0.4
    }
  }));
}

// ─────────────────────────────────────────────────────────────
// Device frame — wraps everything
// ─────────────────────────────────────────────────────────────
function AndroidDevice({
  children,
  width = 412,
  height = 892,
  dark = false,
  title,
  large = false,
  keyboard = false
}) {
  return (
    /*#__PURE__*/
    // data-om-starter: inert presence marker — Claude Design's starter-usage
    // probe reads it; it renders nothing. Keep it on this root element.
    React.createElement("div", {
      "data-om-starter": "android-frame",
      style: {
        width,
        height,
        borderRadius: 18,
        overflow: 'hidden',
        background: dark ? '#1d1b20' : MD_C.surface,
        border: `8px solid ${MD_C.frameBorder}`,
        boxShadow: '0 30px 80px rgba(0,0,0,0.25)',
        display: 'flex',
        flexDirection: 'column',
        boxSizing: 'border-box'
      }
    }, /*#__PURE__*/React.createElement(AndroidStatusBar, {
      dark: dark
    }), title !== undefined && /*#__PURE__*/React.createElement(AndroidAppBar, {
      title: title,
      large: large
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        overflow: 'auto'
      }
    }, children), keyboard && /*#__PURE__*/React.createElement(AndroidKeyboard, null), /*#__PURE__*/React.createElement(AndroidNavBar, {
      dark: dark
    }))
  );
}

// ─────────────────────────────────────────────────────────────
// Keyboard — Gboard (Material 3)
// ─────────────────────────────────────────────────────────────
function AndroidKeyboard() {
  let _k = 0;
  const key = (l, {
    flex = 1,
    bg = MD_C.surface,
    r = 6,
    minW,
    fs = 21
  } = {}) => /*#__PURE__*/React.createElement("div", {
    key: _k++,
    style: {
      height: 46,
      borderRadius: r,
      flex,
      minWidth: minW,
      background: bg,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: 'Roboto, system-ui',
      fontSize: fs,
      color: MD_C.onPrimaryContainer
    }
  }, l);
  const row = (keys, style = {}) => /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6,
      justifyContent: 'center',
      ...style
    }
  }, keys.map(l => key(l)));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: MD_C.inverseOnSurface,
      padding: '0 8px 8px',
      display: 'flex',
      flexDirection: 'column',
      gap: 4
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 44
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, row(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']), row(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'], {
    padding: '0 20px'
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6
    }
  }, key('', {
    bg: MD_C.surfaceVariant
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6,
      flex: 7,
      minWidth: 274
    }
  }, ['z', 'x', 'c', 'v', 'b', 'n', 'm'].map(l => key(l))), key('', {
    bg: MD_C.surfaceVariant
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6
    }
  }, key('?123', {
    bg: MD_C.secondaryContainer,
    r: 100,
    minW: 58,
    fs: 14
  }), key(',', {
    bg: MD_C.surfaceVariant
  }), key('', {
    flex: 3,
    minW: 154
  }), key('.', {
    bg: MD_C.surfaceVariant
  }), key('', {
    bg: MD_C.primaryFixedDim,
    r: 100,
    minW: 58
  }))));
}
Object.assign(window, {
  AndroidDevice,
  AndroidStatusBar,
  AndroidAppBar,
  AndroidListItem,
  AndroidNavBar,
  AndroidKeyboard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/awaken-app/android-frame.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Card = __ds_scope.Card;

__ds_ns.ListItem = __ds_scope.ListItem;

__ds_ns.RepCounter = __ds_scope.RepCounter;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.ProgressSpinner = __ds_scope.ProgressSpinner;

__ds_ns.StatusBanner = __ds_scope.StatusBanner;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Chip = __ds_scope.Chip;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Dialog = __ds_scope.Dialog;

})();
