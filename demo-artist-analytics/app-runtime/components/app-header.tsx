import Image from "next/image"
import { APP_TITLE, LOGO_SRC } from "@/lib/constants"

export function AppHeader() {
  return (
    <header className="sticky top-0 z-50 w-full border-b border-border bg-[var(--brand-nav-bg)] text-[var(--brand-nav-fg)]">
      <div className="w-full px-4 h-14 flex items-center gap-3">
        {LOGO_SRC && (
          <Image
            src={LOGO_SRC}
            alt={`${APP_TITLE} logo`}
            width={28}
            height={28}
            className="shrink-0"
          />
        )}
        <span className="text-sm font-semibold tracking-tight">
          {APP_TITLE}
        </span>
      </div>
    </header>
  )
}
