import { clsx } from "clsx";
import { useIsMobile } from "@/hooks/useIsMobile";
import { OuterSidebar } from "./OuterSidebar";
import { InnerSidebar } from "./InnerSidebar";
import { MobileTabBar } from "./MobileTabBar";

interface MainLayoutProps {
  children: React.ReactNode;
}

export function MainLayout({ children }: MainLayoutProps) {
  const isMobile = useIsMobile();

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-dark-bg">
      {!isMobile && <OuterSidebar />}
      {!isMobile && <InnerSidebar />}
      <main
        className={clsx(
          "flex-1 overflow-hidden flex flex-col",
          isMobile && "pb-14",
        )}
      >
        {children}
      </main>
      {isMobile && <MobileTabBar />}
    </div>
  );
}
