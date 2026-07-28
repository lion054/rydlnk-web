"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui";

export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    // Replace with your error reporter before launch.
    console.error(error);
  }, [error]);

  return (
    <main id="main" className="grid min-h-screen place-items-center bg-shell px-6">
      <div className="max-w-[46ch] text-center">
        <span className="font-mono text-[0.7rem] font-semibold uppercase tracking-[0.18em] text-flag">
          Something broke
        </span>
        <h1 className="h2 mt-3">That didn&apos;t load.</h1>
        <p className="mt-4 text-muted">
          The error has been logged. Try again — if it keeps happening, the rest of the site is still working.
        </p>
        <div className="mt-7 flex flex-wrap justify-center gap-3">
          <Button onClick={reset}>Try again</Button>
          <Button href="/" variant="ghost">
            Back to the start
          </Button>
        </div>
        {error.digest ? (
          <p className="mt-6 font-mono text-[0.7rem] text-muted">Reference {error.digest}</p>
        ) : null}
      </div>
    </main>
  );
}
