"use client";

import { useEffect } from "react";
import * as Sentry from "@sentry/nextjs";

export default function GlobalError({ error }: { error: Error & { digest?: string } }) {
  useEffect(() => { Sentry.captureException(error); }, [error]);
  return (
    <html lang="en">
      <body>
        <main style={{ fontFamily: "sans-serif", maxWidth: 640, margin: "15vh auto", padding: 24 }}>
          <h1>Rydlnk could not load</h1>
          <p>The error has been reported. Refresh the page or try again shortly.</p>
          {error.digest ? <p>Reference: {error.digest}</p> : null}
        </main>
      </body>
    </html>
  );
}
