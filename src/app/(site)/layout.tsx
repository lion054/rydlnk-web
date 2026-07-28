import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

/**
 * Shell for every public page.
 *
 * Previously the two tracks each had their own layout that stacked a header, a
 * subnav rendering the same links, and a sequential pager. One header now, and
 * pages opt into a `NextSteps` block where onward reading actually helps.
 */
export default function SiteLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <SiteHeader />
      <main id="main">{children}</main>
      <SiteFooter />
    </>
  );
}
