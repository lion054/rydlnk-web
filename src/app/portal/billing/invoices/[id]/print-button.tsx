"use client";

import { Button } from "@/components/ui";
import * as Icon from "@/components/icons";

export function PrintButton() {
  return (
    <Button size="sm" onClick={() => window.print()}>
      <Icon.Receipt size={15} />
      Print / save PDF
    </Button>
  );
}
