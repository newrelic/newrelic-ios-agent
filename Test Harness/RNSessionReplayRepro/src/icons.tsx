// react-native-svg icons, like the ones in the Levi's screens (the NR-652282 replay had
// 55 RNSVGSvgView icons and no image icons).
import React from 'react';
import Svg, { Circle, Path } from 'react-native-svg';

type IconProps = { size?: number; color?: string };

export function BackIcon({ size = 24, color = '#111111' }: IconProps) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path d="M20 12H5M11 5l-7 7 7 7" stroke={color} strokeWidth={2} fill="none" />
    </Svg>
  );
}

export function SearchIcon({ size = 24, color = '#111111' }: IconProps) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Circle cx={10} cy={10} r={6.5} stroke={color} strokeWidth={2} fill="none" />
      <Path d="M15 15l6 6" stroke={color} strokeWidth={2} />
    </Svg>
  );
}

export function HeartIcon({ size = 24, color = '#111111', filled = false }: IconProps & { filled?: boolean }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path
        d="M12 20.5s-7.5-4.6-7.5-10.1C4.5 7.6 6.6 5.5 9.2 5.5c1.3 0 2.2.6 2.8 1.5.6-.9 1.5-1.5 2.8-1.5 2.6 0 4.7 2.1 4.7 4.9 0 5.5-7.5 10.1-7.5 10.1z"
        stroke={color}
        strokeWidth={1.8}
        fill={filled ? color : 'none'}
      />
    </Svg>
  );
}
