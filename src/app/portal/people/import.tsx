"use client";

import { useState, useTransition } from "react";
import { Panel } from "@/components/portal/chrome";
import { Button, Chip } from "@/components/ui";
import * as Icon from "@/components/icons";
import { importRoster, type ImportRow } from "../actions";

/**
 * Roster CSV import.
 *
 * Parsed and previewed in the browser before anything is sent, because a bad
 * column mapping discovered after the write is a cleanup job. The minimum is an
 * email; employee number, department and cost center are matched by header name
 * where present.
 */

const HEADERS: Record<string, keyof ImportRow> = {
  email: "email",
  "work email": "email",
  "email address": "email",
  "employee number": "employee_no",
  "employee no": "employee_no",
  "employee id": "employee_no",
  employee_no: "employee_no",
  department: "department",
  dept: "department",
  "cost center": "cost_center",
  "cost centre": "cost_center",
  cost_center: "cost_center",
  role: "role",
  title: "job_title",
  "job title": "job_title",
};

/** Handles quoted fields and embedded commas — a real roster export has both. */
function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;

  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (c === '"') {
        quoted = false;
      } else {
        cell += c;
      }
      continue;
    }
    if (c === '"') quoted = true;
    else if (c === ",") {
      row.push(cell.trim());
      cell = "";
    } else if (c === "\n" || c === "\r") {
      if (cell || row.length) {
        row.push(cell.trim());
        rows.push(row);
        row = [];
        cell = "";
      }
      if (c === "\r" && text[i + 1] === "\n") i++;
    } else cell += c;
  }
  if (cell || row.length) {
    row.push(cell.trim());
    rows.push(row);
  }
  return rows.filter((r) => r.some(Boolean));
}

export function RosterImport({ companyId }: { companyId: string }) {
  const [rows, setRows] = useState<ImportRow[] | null>(null);
  const [skipped, setSkipped] = useState(0);
  const [fileName, setFileName] = useState("");
  const [pending, startTransition] = useTransition();
  const [result, setResult] = useState<string | null>(null);

  function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setFileName(file.name);
    setResult(null);

    file.text().then((text) => {
      const grid = parseCsv(text);
      if (grid.length < 2) {
        setRows([]);
        setSkipped(0);
        return;
      }
      const header = grid[0].map((h) => h.toLowerCase().trim());
      const parsed: ImportRow[] = [];
      let bad = 0;

      for (const line of grid.slice(1)) {
        const rec: Partial<ImportRow> = {};
        header.forEach((h, i) => {
          const key = HEADERS[h];
          if (key) rec[key] = line[i] ?? "";
        });
        if (rec.email && /.+@.+\..+/.test(rec.email)) parsed.push(rec as ImportRow);
        else bad++;
      }
      setRows(parsed);
      setSkipped(bad);
    });
  }

  function send() {
    if (!rows?.length) return;
    startTransition(async () => {
      const res = await importRoster(companyId, rows);
      setResult(res.ok ? res.message : res.error);
      if (res.ok) setRows(null);
    });
  }

  return (
    <Panel title="Import a roster">
      <div className="p-5 lg:p-6">
        <div className="flex flex-wrap items-center gap-4">
          <label className="inline-flex min-h-[44px] cursor-pointer items-center gap-2 rounded-full border border-linestrong px-5 text-base font-semibold transition-colors hover:border-signal hover:bg-signal/5">
            <Icon.Users size={17} />
            {fileName || "Choose a CSV"}
            <input type="file" accept=".csv,text/csv" onChange={onFile} className="sr-only" />
          </label>
          {rows ? (
            <span className="flex items-center gap-2 text-base text-muted">
              <Chip tone="ok">{rows.length} valid</Chip>
              {skipped > 0 ? <Chip tone="warn">{skipped} skipped</Chip> : null}
            </span>
          ) : null}
        </div>

        <p className="mt-3 text-xs text-muted">
          Minimum column: <span className="font-mono">email</span>. Also read if present:{" "}
          <span className="font-mono">employee number</span>, <span className="font-mono">department</span>,{" "}
          <span className="font-mono">cost center</span>, <span className="font-mono">job title</span>,{" "}
          <span className="font-mono">role</span>. Everything is previewed before anything is written.
        </p>

        {rows && rows.length > 0 ? (
          <>
            <div className="mt-5 max-h-64 overflow-auto rounded-card border border-line">
              <table className="w-full text-base">
                <thead className="sticky top-0 bg-[#fafbfa]">
                  <tr>
                    {["Email", "Employee no", "Department", "Cost center", "Role"].map((h) => (
                      <th key={h} className="border-b border-line px-4 py-2 text-left text-2xs font-semibold uppercase tracking-[0.09em] text-muted">
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {rows.slice(0, 50).map((r, i) => (
                    <tr key={`${r.email}-${i}`} className="border-b border-line last:border-b-0">
                      <td className="px-4 py-2">{r.email}</td>
                      <td className="nums px-4 py-2 text-muted">{r.employee_no || "—"}</td>
                      <td className="px-4 py-2 text-muted">{r.department || "—"}</td>
                      <td className="nums px-4 py-2 text-muted">{r.cost_center || "—"}</td>
                      <td className="px-4 py-2 text-muted">{r.role || "viewer"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {rows.length > 50 ? (
              <p className="mt-2 text-xs text-muted">Showing the first 50 of {rows.length}.</p>
            ) : null}

            <div className="mt-5 flex flex-wrap items-center gap-3">
              <Button onClick={send} disabled={pending}>
                {pending ? "Importing…" : `Create ${rows.length} invites`}
                {!pending ? <Icon.ArrowRight size={16} /> : null}
              </Button>
              <Button variant="ghost" onClick={() => setRows(null)}>
                Cancel
              </Button>
              <p className="text-xs text-muted">
                Creates an invite each — nobody is added until they accept.
              </p>
            </div>
          </>
        ) : null}

        {rows && rows.length === 0 ? (
          <p className="mt-4 text-base text-flag">
            No usable rows. Check there&apos;s a header line and an email column.
          </p>
        ) : null}

        {result ? (
          <p role="status" className="mt-5 flex items-center gap-2.5 text-base">
            <Icon.Check size={17} className="text-signal" />
            {result}
          </p>
        ) : null}
      </div>
    </Panel>
  );
}
