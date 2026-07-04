import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';

// ConsentBanner — DPDPA Section 6 + Rule 3 notice requirements.
// Every checkbox starts unchecked: consent must be a clear affirmative
// action, per purpose, and never bundled with unrelated terms.
export default function ConsentBanner({ onSubmit }) {
  const { t } = useTranslation();
  const [choices, setChoices] = useState({ service: false, marketing: false });

  const toggle = (purpose) => setChoices((c) => ({ ...c, [purpose]: !c[purpose] }));

  return (
    <section role="dialog" aria-label={t('consent.title')}>
      <p>{t('consent.notice')}</p>
      <label>
        <input type="checkbox" checked={choices.service} onChange={() => toggle('service')} />
        {t('consent.purpose.service')}
      </label>
      <label>
        <input type="checkbox" checked={choices.marketing} onChange={() => toggle('marketing')} />
        {t('consent.purpose.marketing')}
      </label>
      <a href="/privacy_policy">{t('consent.readNotice')}</a>
      <button onClick={() => onSubmit(choices)}>{t('consent.save')}</button>
    </section>
  );
}
