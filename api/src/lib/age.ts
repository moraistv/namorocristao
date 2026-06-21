/** Calcula a idade em anos a partir da data de nascimento. */
export function ageFromBirthday(birthday: Date): number {
  const today = new Date();
  let age = today.getFullYear() - birthday.getFullYear();
  const m = today.getMonth() - birthday.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < birthday.getDate())) {
    age--;
  }
  return age;
}

export const MIN_AGE = 18;

export function isAdult(birthday: Date): boolean {
  return ageFromBirthday(birthday) >= MIN_AGE;
}
