export function englishDigits(text: string) {
  return text.replace(/[٠-٩۰-۹]/g, digit =>
    String(digit.charCodeAt(0) - (digit <= "٩" ? 0x660 : 0x6f0)));
}
