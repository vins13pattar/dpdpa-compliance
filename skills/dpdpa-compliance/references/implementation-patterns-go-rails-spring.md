# DPDPA Implementation Patterns — Go, Ruby on Rails, Spring Boot

Production-ready DPDPA compliance patterns for Go (net/http), Ruby on Rails, and
Java Spring Boot. Database schemas are shared with `implementation-patterns.md`
(Section 1) — the patterns below show the application layer for each stack.
Each pattern references the DPDPA section and DPDP Rules 2025 rule it implements.

---

## 1. Go (net/http) Patterns

### Consent Middleware — Sections 4-6

```go
// consent/middleware.go
// DPDPA Section 6: only process personal data with valid, purpose-specific
// consent (or a Section 7 legitimate use, which must be handled explicitly).
package consent

import (
	"context"
	"database/sql"
	"net/http"
)

type contextKey string

const ConsentVerified contextKey = "dpdpa.consent.verified"

// RequirePurpose gates a handler on granted consent for one purpose.
// Return 403 with a machine-readable code so clients can re-prompt.
func RequirePurpose(db *sql.DB, purpose string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID := UserIDFromContext(r.Context())
			var granted bool
			err := db.QueryRowContext(r.Context(),
				`SELECT is_granted FROM user_consents uc
				 JOIN consent_purposes p ON p.id = uc.purpose_id
				 WHERE uc.user_id = $1 AND p.slug = $2`,
				userID, purpose).Scan(&granted)
			if err != nil || !granted {
				http.Error(w, `{"error":"consent_required","purpose":"`+purpose+`"}`,
					http.StatusForbidden)
				return
			}
			ctx := context.WithValue(r.Context(), ConsentVerified, purpose)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
```

### Recording and Withdrawing Consent — Section 6(4)

```go
// consent/record.go
// Append-only consent ledger: who, what purpose, which notice version, how.
// Withdrawal must be as easy as granting (Section 6(4)) — same endpoint shape.
func Record(ctx context.Context, db *sql.DB, rec ConsentEvent) error {
	_, err := db.ExecContext(ctx,
		`INSERT INTO consent_records
		   (user_id, purpose_id, action, notice_version, consent_method, ip_address)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		rec.UserID, rec.PurposeID, rec.Action, rec.NoticeVersion, rec.Method, rec.IP)
	if err != nil {
		return err
	}
	_, err = db.ExecContext(ctx,
		`INSERT INTO user_consents (user_id, purpose_id, is_granted, last_updated)
		 VALUES ($1, $2, $3, NOW())
		 ON CONFLICT (user_id, purpose_id)
		 DO UPDATE SET is_granted = $3, last_updated = NOW()`,
		rec.UserID, rec.PurposeID, rec.Action == "granted")
	return err
}
```

### Right to Access and Erasure — Sections 11-12

```go
// rights/handlers.go
package rights

// Export returns everything held about the Data Principal plus the
// identities of Data Fiduciaries/Processors it was shared with (Section 11).
func Export(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := UserIDFromContext(r.Context())
		bundle, err := collectUserData(r.Context(), db, userID) // user row, consents, activity
		if err != nil {
			http.Error(w, `{"error":"export_failed"}`, http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Disposition", `attachment; filename="my-data.json"`)
		json.NewEncoder(w).Encode(bundle)
	}
}

// Erase queues deletion. Rule 8(2): notify the Data Principal at least
// 48 hours before erasure so they can object or take a copy.
func Erase(db *sql.DB, notifier Notifier) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := UserIDFromContext(r.Context())
		eraseAt := time.Now().Add(48 * time.Hour)
		_, err := db.ExecContext(r.Context(),
			`INSERT INTO erasure_queue (user_id, erase_at, status) VALUES ($1, $2, 'notified')`,
			userID, eraseAt)
		if err != nil {
			http.Error(w, `{"error":"erasure_failed"}`, http.StatusInternalServerError)
			return
		}
		notifier.PreErasureNotice(userID, eraseAt)
		w.WriteHeader(http.StatusAccepted)
		json.NewEncoder(w).Encode(map[string]any{"erase_at": eraseAt})
	}
}
```

### Breach Notification Worker — Section 8(6), Rule 7

```go
// breach/notify.go
// Rule 7: notify the Data Protection Board without delay and follow up
// within 72 hours with full details; notify each affected Data Principal.
func (s *Service) HandleConfirmedBreach(ctx context.Context, b Breach) error {
	if err := s.notifyBoardInitial(ctx, b); err != nil { // without delay
		return err
	}
	s.scheduler.At(b.ConfirmedAt.Add(72*time.Hour), func() {
		s.notifyBoardDetailed(context.Background(), b.ID) // deadline, Rule 7(2)
	})
	return s.notifyAffectedPrincipals(ctx, b.ID) // plain-language notice, Rule 7(1)
}
```

---

## 2. Ruby on Rails Patterns

### Migration — Consent Ledger

```ruby
# db/migrate/20260704000001_create_dpdpa_consent_tables.rb
class CreateDpdpaConsentTables < ActiveRecord::Migration[7.1]
  def change
    create_table :consent_purposes do |t|
      t.string :slug, null: false, index: { unique: true }
      t.string :title, null: false
      t.text :description, null: false     # plain language — Rule 3
      t.boolean :is_required, default: false
      t.timestamps
    end

    # Append-only: no update/destroy path in the model.
    create_table :consent_records do |t|
      t.references :user, null: false
      t.references :consent_purpose, null: false
      t.string :action, null: false        # 'granted' | 'withdrawn'
      t.string :notice_version, null: false
      t.string :consent_method, null: false
      t.datetime :created_at, null: false
    end
  end
end
```

### Consent Concern — Sections 4-6

```ruby
# app/controllers/concerns/dpdpa_consent.rb
module DpdpaConsent
  extend ActiveSupport::Concern

  # before_action -> { require_consent!("analytics") }
  def require_consent!(purpose_slug)
    granted = ConsentRecord
      .joins(:consent_purpose)
      .where(user: current_user, consent_purposes: { slug: purpose_slug })
      .order(:created_at).last&.action == "granted"

    return if granted

    render json: { error: "consent_required", purpose: purpose_slug },
           status: :forbidden
  end
end
```

```ruby
# app/models/consent_record.rb
class ConsentRecord < ApplicationRecord
  belongs_to :user
  belongs_to :consent_purpose

  # Section 6: the ledger is evidence — never rewrite history.
  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
```

### Data Principal Rights Controller — Sections 11-13

```ruby
# app/controllers/data_rights_controller.rb
class DataRightsController < ApplicationController
  before_action :authenticate_user!

  # GET /my-data — Section 11 right to access
  def export
    send_data current_user.dpdpa_export.to_json,
              filename: "my-data-#{Date.current}.json",
              type: :json
  end

  # DELETE /my-account — Section 12 erasure with Rule 8(2) 48-hour notice
  def destroy
    erase_at = 48.hours.from_now
    ErasureRequest.create!(user: current_user, erase_at: erase_at)
    DataPrincipalMailer.pre_erasure_notice(current_user, erase_at).deliver_later
    EraseUserJob.set(wait_until: erase_at).perform_later(current_user.id)
    render json: { erase_at: erase_at }, status: :accepted
  end

  # POST /grievances — Section 13, Rule 14(3): respond within 90 days
  def create_grievance
    grievance = current_user.grievances.create!(
      subject: params.require(:subject),
      due_at: 90.days.from_now
    )
    GrievanceMailer.acknowledgement(grievance).deliver_later
    render json: grievance, status: :created
  end
end
```

### Children's Data — Section 9, Rule 10

```ruby
# app/models/concerns/child_protection.rb
module ChildProtection
  extend ActiveSupport::Concern

  included do
    scope :children, -> { where(is_child: true) }
    before_save :flag_child_account
  end

  def flag_child_account
    self.is_child = date_of_birth.present? && date_of_birth > 18.years.ago
  end

  # Rule 10: verifiable parental consent before any processing; Section 9(3):
  # no tracking, behavioural monitoring, or targeted ads for children.
  def processing_allowed?
    !is_child || parental_consent_verified?
  end

  def tracking_allowed?
    !is_child
  end
end
```

---

## 3. Spring Boot (Java) Patterns

### Consent Entity and Repository — Sections 4-6

```java
// consent/ConsentRecord.java
// Append-only ledger: no setters for recorded fields, no delete path.
@Entity
@Table(name = "consent_records")
public class ConsentRecord {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false) private UUID userId;
    @Column(nullable = false) private String purposeSlug;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false) private ConsentAction action;   // GRANTED, WITHDRAWN

    @Column(nullable = false) private String noticeVersion;    // Rule 3 notice shown
    @Column(nullable = false) private String consentMethod;
    @CreationTimestamp private Instant createdAt;

    protected ConsentRecord() {}
    public ConsentRecord(UUID userId, String purposeSlug, ConsentAction action,
                         String noticeVersion, String consentMethod) { /* assign */ }
}
```

### Consent Guard — Method-Level Enforcement

```java
// consent/RequiresConsent.java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequiresConsent {
    String purpose();
}

// consent/ConsentAspect.java
// DPDPA Section 6: block processing when purpose-specific consent is absent.
@Aspect
@Component
public class ConsentAspect {
    private final ConsentService consents;

    @Before("@annotation(requiresConsent)")
    public void check(JoinPoint jp, RequiresConsent requiresConsent) {
        UUID userId = CurrentUser.id();
        if (!consents.isGranted(userId, requiresConsent.purpose())) {
            throw new ConsentRequiredException(requiresConsent.purpose()); // -> 403
        }
    }
}
```

Usage:

```java
@RequiresConsent(purpose = "marketing")
public void sendCampaign(UUID userId) { /* ... */ }
```

### Data Principal Rights Controller — Sections 11-13

```java
// rights/DataRightsController.java
@RestController
@RequestMapping("/api/rights")
public class DataRightsController {
    private final RightsService rights;

    // Section 11: right to access
    @GetMapping("/export")
    public ResponseEntity<UserDataBundle> export(@AuthenticationPrincipal AppUser user) {
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=my-data.json")
            .body(rights.export(user.getId()));
    }

    // Section 12: erasure with Rule 8(2) 48-hour pre-erasure notice
    @DeleteMapping("/account")
    public ResponseEntity<Map<String, Instant>> erase(@AuthenticationPrincipal AppUser user) {
        Instant eraseAt = rights.scheduleErasure(user.getId(), Duration.ofHours(48));
        return ResponseEntity.accepted().body(Map.of("eraseAt", eraseAt));
    }

    // Section 13, Rule 14(3): grievance with 90-day SLA tracking
    @PostMapping("/grievances")
    public ResponseEntity<Grievance> grievance(@AuthenticationPrincipal AppUser user,
                                               @Valid @RequestBody GrievanceRequest req) {
        Grievance g = rights.openGrievance(user.getId(), req.subject(),
                                           Instant.now().plus(Duration.ofDays(90)));
        return ResponseEntity.status(HttpStatus.CREATED).body(g);
    }
}
```

### Retention Job — Section 8(7), Rule 8

```java
// retention/RetentionJob.java
// Erase personal data once its purpose is served, honouring Third Schedule
// periods and Rule 6(e)'s minimum 1-year log retention.
@Component
public class RetentionJob {
    private final JdbcTemplate jdbc;

    @Scheduled(cron = "0 0 3 * * *") // nightly
    public void purgeExpired() {
        jdbc.update("""
            DELETE FROM user_activity
            WHERE created_at < NOW() - INTERVAL '365 days'
              AND user_id NOT IN (SELECT user_id FROM legal_holds)
            """);
    }
}
```

### Breach Notification — Section 8(6), Rule 7

```java
// breach/BreachNotificationService.java
@Service
public class BreachNotificationService {
    // Rule 7(1): notify affected Data Principals without delay, in plain
    // language, with what happened and what they should do.
    // Rule 7(2): notify the Board without delay, full details within 72 hours.
    @EventListener
    public void onBreachConfirmed(BreachConfirmedEvent event) {
        boardClient.initialReport(event.breach());
        scheduler.schedule(() -> boardClient.detailedReport(event.breach().id()),
                           event.confirmedAt().plus(Duration.ofHours(72)));
        affectedUsers(event.breach()).forEach(user ->
            notifier.breachNotice(user, event.breach()));
    }
}
```

---

## Stack-Agnostic Reminders

- The consent ledger is append-only in every stack — evidence of consent is an
  obligation (Section 6), not a convenience.
- Withdrawal endpoints must be no harder to call than grant endpoints (Section 6(4)).
- Erasure flows need the Rule 8(2) 48-hour pre-erasure notice and must respect
  legal holds and Third Schedule retention periods.
- Child accounts (Section 9): verifiable parental consent before processing,
  and no tracking, behavioural monitoring, or targeted advertising.
- Every personal-data route sits behind authentication, rate limiting, and
  purpose-checked consent — see `audit-checklist.md` Sections A and D.
