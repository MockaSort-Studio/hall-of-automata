# ONBOARDING TEST REPORT

## INVOKER

### TC-INV-01 — Invoker onboarding: environment provisioned on label

**Result** : passed

**Remarks**: None

---

### TC-INV-02 — Invoker onboarding: secret check gates test-token job

**Result** : passed

**Remarks**: None

---

### TC-INV-03 ★ — Invoker onboarding: successful token validation and finalization

**Result** passed 

**Remarks**: 
- End comment should be changed: invokation possible only by commenting @hall-of-automata
- Token validation still week : curl result 000 as pass is flaky

---

### TC-INV-04 — Invoker onboarding: bad token produces retry prompt

**Result** : passed

**Remarks**: None

---

### TC-INV-05 — Invoker onboarding: valid token, quota exhausted → queued

**Result** : passed

**Remarks**: 
- Token validation still week : curl result 000 as pass is flaky

---

### TC-AUT-01 ★ — Automaton onboarding: character sheet passes, full provisioning

**Result** : passed

**Remarks**: None

---

### TC-AUT-02 — Automaton onboarding: incomplete sheet → clarifying questions

**Result** : passed

**Remarks**: 
- great handling of unexpected case for duplicated automata

---

### TC-AUT-03 — Automaton onboarding: invoker addresses feedback, provisioning completes

**Result** : passed

**Remarks**: 
- great handling of unexpected close request by invoker

---

### TC-AUT-04 — Automaton onboarding: re-analyze still finds gaps

**Result** : passed

**Remarks**: 
- great handling of unexpected case duplicated automata



## CODE REVIEW
- scripting lines for either bash or git scripting must have their own file, not implemented in action body

