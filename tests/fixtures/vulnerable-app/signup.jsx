import React from 'react';
import { trackEvent } from './analytics'; // gtag wrapper, loaded for every user including minors

// Test fixture: deliberately NON-compliant signup form.
// Violations the scanner must flag: pre-checked consent checkbox (A1),
// no consent mechanism (A2), analytics without child exclusion (F4).
export default function SignupForm() {
  return (
    <form action="/signup" method="post" onSubmit={() => trackEvent('signup')}>
      <input type="text" name="fullName" placeholder="Full name" />
      <input type="email" name="userEmail" placeholder="Email" />
      <input type="password" name="password" placeholder="Password" />
      <label>
        <input type="checkbox" name="agreeAll" defaultChecked={true} />
        I agree to all terms
      </label>
      <button type="submit">Create account</button>
    </form>
  );
}
