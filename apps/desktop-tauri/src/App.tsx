import { translate } from "./i18n";

export default function App() {
  return (
    <main className="app-shell">
      <aside className="app-sidebar">
        <div className="app-brand">
          <h1 className="app-brand-title">{translate("app.name")}</h1>
          <span className="app-brand-subtitle">{translate("app.subtitle")}</span>
        </div>
      </aside>
      <section className="app-main">
        <div className="app-panel">{translate("nav.quotaMonitoring")}</div>
      </section>
    </main>
  );
}
