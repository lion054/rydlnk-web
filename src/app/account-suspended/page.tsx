import { contact, mailtoWork } from "@/lib/site";

export const metadata = { title: "Account suspended" };

export default function AccountSuspendedPage() {
  return (
    <main className="grid min-h-screen place-items-center bg-shell px-6">
      <div className="max-w-xl rounded-lg border border-line bg-white p-8 text-center">
        <p className="eyebrow text-flag">Company access paused</p>
        <h1 className="mt-3 font-display text-3xl font-extrabold">This company account is suspended.</h1>
        <p className="mt-4 text-base text-muted">
          Company-funded bookings and administration are unavailable. Existing records remain protected and
          no balances have been deleted.
        </p>
        <a className="mt-6 inline-flex rounded-full bg-ink px-6 py-3 font-semibold text-white" href={mailtoWork}>
          Contact {contact.workEmail}
        </a>
      </div>
    </main>
  );
}
