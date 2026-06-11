import { Radar } from "lucide-react";

export function AboutPage() {
  return (
    <div className="about-page">
      <section className="about-card">
        <div className="about-mark" aria-hidden="true">
          <Radar size={34} strokeWidth={2.1} />
        </div>
        <div>
          <h1>Quota Radar</h1>
          <p>Tauri desktop preview</p>
        </div>
        <dl>
          <div>
            <dt>Platform target</dt>
            <dd>macOS, Windows, Linux</dd>
          </div>
          <div>
            <dt>Implementation stage</dt>
            <dd>Mock UI first, backend contracts next</dd>
          </div>
          <div>
            <dt>Data policy</dt>
            <dd>No real provider secrets in preview data</dd>
          </div>
        </dl>
      </section>
    </div>
  );
}
