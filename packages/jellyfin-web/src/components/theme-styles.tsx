import React from 'react';
import { createPortal } from 'react-dom';
import { themeVariables } from '@aiostreams/ui/utils/palette';
import { settings, useSetting, CUSTOM_CSS_OFF } from '../lib/settings';
import { useSystemTheme } from '../lib/hosts/shell';

/** Last on the page, so the user's colours and CSS win ties. */
export function ThemeStyles() {
  const [colors] = useSetting(settings.themeColors);
  const [css] = useSetting(settings.customCss);
  const system = useSystemTheme();
  // The desktop's theme fills in whatever the user hasn't picked.
  const vars = React.useMemo(
    () =>
      Object.entries(
        themeVariables({
          accent: colors.accent || system?.accent,
          background: colors.background || system?.background,
        })
      )
        .map(([name, value]) => `${name}: ${value};`)
        .join(' '),
    [colors, system]
  );
  return createPortal(
    <>
      {vars && <style data-ui="theme-colors">{`:root { ${vars} }`}</style>}
      {css && !CUSTOM_CSS_OFF && <style data-ui="custom-css">{css}</style>}
    </>,
    document.body
  );
}
