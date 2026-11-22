import { useId } from "react";

type OrnamentalFrameProps = {
  className?: string;
};

/** Shared gold-and-deep-green frame used around the display and its content panels. */
export function OrnamentalFrame({ className = "" }: OrnamentalFrameProps) {
  const id = useId().replace(/:/g, "");
  return (
    <svg
      className={`islamic-ornamental-frame ${className}`}
      viewBox="0 0 1000 600"
      preserveAspectRatio="none"
      aria-hidden="true"
      focusable="false"
    >
      <defs>
        <g id={`${id}-corner`}>
          <path d="M4 158V54Q4 5 54 5h111M12 146V57Q12 14 57 14h74M21 134V62Q21 23 62 23h54" />
          <path d="M5 112c21-27 46-20 50-47 3-20-16-30-12-46 5-18 28-19 39-5 12 15-2 33-14 38-14 7-17 24-4 35 15 13 38 3 48-17 8-17 8-37 33-59" />
          <path d="M11 91c17-17 32-10 42-27m-37 50c24-12 39-2 51-19 12-16 4-31-8-34m43 1c17 5 31-3 42-22M35 15c0 25 20 27 29 42 9 14 5 29-9 39m25 34c4-19 22-28 39-25 18 3 28-8 34-24" />
          <path d="M18 143c12-4 23-3 31 4m-27-12c-1-15 10-24 25-22 15 2 21 13 29 23m-8-100c-13-3-18-14-15-24m31 33c15 8 18 24 12 36m20-26c-9-12-5-23 6-30m5 73c16-9 27-5 37 5" />
          <path d="M13 79c-10-15-8-27 5-31 15-4 24 10 15 20-7 8-18 2-15-6m28 58c-13-12-10-27 2-30 13-4 22 8 14 17-6 7-16 3-14-4m73-60c-3-16 8-26 20-20 12 7 8 20-1 22-7 2-12-5-7-10m-11 75c-13-12-10-25 3-29 13-4 22 7 14 17-6 7-15 4-14-3" />
          <path d="M19 66c14-4 21 5 27 16m-20 33c11-12 22-11 32-4m-11-81c7 12 18 17 30 16m4 49c8-16 21-20 34-15m-2-51c-2 13 6 22 18 24m-22 46c15-3 25 4 31 15" />
          <path className="islamic-frame-fill" d="M17 29c12-12 22-12 30 0-8 12-18 12-30 0Zm36 27c12-13 24-11 31 2-10 11-21 11-31-2Zm16 48c12-13 24-11 31 2-10 11-21 11-31-2Zm48-55c12-13 23-10 29 3-10 10-20 9-29-3Z" />
          <circle cx="18" cy="18" r="4" />
          <circle cx="48" cy="48" r="3" />
          <circle cx="93" cy="24" r="3" />
          <circle cx="53" cy="114" r="3" />
          <circle cx="139" cy="94" r="3" />
          <path d="m17 53 7 8-7 8-7-8 7-8Zm38 18 6 7-6 7-6-7 6-7Zm40-42 6 7-6 7-6-7 6-7Zm30 61 6 7-6 7-6-7 6-7Z" />
        </g>
        <g id={`${id}-medallion`}>
          <path d="M0-31 8-16 20-23 19-8 34 0 19 8 20 23 8 16 0 31-8 16-20 23-19 8-34 0-19-8-20-23-8-16Z" />
          <path d="M0-23 5-10 15-16 13-5 25 0 13 5 15 16 5 10 0 23-5 10-15 16-13 5-25 0-13-5-15-16-5-10Z" />
          <path d="M0-13 4-4 13 0 4 4 0 13-4 4-13 0-4-4Z" />
          <circle r="3.2" />
        </g>
      </defs>

      <g className="islamic-frame-shadow">
        <rect x="9" y="9" width="982" height="582" rx="10" />
        <rect x="17" y="17" width="966" height="566" rx="7" />
        <rect x="25" y="25" width="950" height="550" rx="5" />
      </g>
      <g className="islamic-frame-rail">
        <rect x="9" y="9" width="982" height="582" rx="10" />
        <rect x="17" y="17" width="966" height="566" rx="7" />
        <rect x="25" y="25" width="950" height="550" rx="5" />
      </g>
      <g className="islamic-frame-detail">
        <use href={`#${id}-corner`} transform="translate(2 2) scale(.7)" />
        <use href={`#${id}-corner`} transform="translate(998 2) scale(-.7 .7)" />
        <use href={`#${id}-corner`} transform="translate(2 598) scale(.7 -.7)" />
        <use href={`#${id}-corner`} transform="translate(998 598) scale(-.7 -.7)" />
        <use href={`#${id}-medallion`} transform="translate(500 17)" />
        <use href={`#${id}-medallion`} transform="translate(500 583)" />
        <path d="M180 17h285m70 0h285M180 583h285m70 0h285M17 190v110m0 40v110M983 190v110m0 40v110" />
      </g>
      <g className="islamic-frame-detail">
        <use href={`#${id}-medallion`} transform="translate(500 17)" />
        <use href={`#${id}-medallion`} transform="translate(500 583)" />
      </g>
    </svg>
  );
}
