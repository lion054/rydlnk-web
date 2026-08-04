# Super-admin operations

Super-admin access is represented only by an active `operations_admin` row in
`platform_staff`. It is separate from every company role.

## Bootstrap

Create the first administrator from the Supabase SQL editor using an existing
Auth user UUID:

```sql
insert into public.platform_staff(user_id, role, active)
values ('AUTH-USER-UUID', 'operations_admin', true)
on conflict(user_id) do update
set role = excluded.role, active = true;
```

After bootstrap, use `/ops/admin` to grant or revoke platform access. The
application prevents self-deactivation and removal of the last active
operations administrator.

## Controls

- Suspend/reactivate companies.
- Disable/re-enable individual Auth accounts.
- Review private driver documents and approve/reject drivers.
- View recent company funding and issue full Stripe top-up refunds.
- Manage dispatchers and operations administrators.
- Review immutable platform audit history.
- Open dispatch and financial-health consoles.

Every mutation requires a reason. Company suspension is enforced in database
authorization helpers, not just hidden in the interface.

## Refund safety

A top-up refund:

1. reserves the matching credits from the company float;
2. creates an idempotent Stripe refund;
3. moves the reservation to the external account and marks the top-up refunded.

If Stripe rejects the refund, the reservation is released. If database
finalization fails after Stripe succeeds, the reservation remains held and a
retry completes the same Stripe refund without returning credits twice.

Only full top-up refunds are supported. Manual ledger editing and partial
refunds are deliberately unavailable.

