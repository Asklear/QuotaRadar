import { GripVertical, X } from "lucide-react";
import { providerRegistry } from "../shared/mockData";
import type { ProviderCategory } from "../shared/types";

interface ProviderOrderDialogProps {
  open: boolean;
  onClose: () => void;
}

const categories: ProviderCategory[] = ["AI Search", "LLM"];

export function ProviderOrderDialog({ open, onClose }: ProviderOrderDialogProps) {
  if (!open) {
    return null;
  }

  return (
    <div className="dialog-backdrop">
      <section className="provider-order-dialog" role="dialog" aria-label="Provider order">
        <header className="provider-order-header">
          <div>
            <h2>Provider order</h2>
            <p>Drag providers inside each category in a later persistence phase.</p>
          </div>
          <button aria-label="Close provider order" onClick={onClose}>
            <X size={16} />
          </button>
        </header>
        <div className="provider-order-body">
          {categories.map((category) => (
            <fieldset className="provider-order-group" key={category} aria-label={category}>
              <legend>{category}</legend>
              {providerRegistry
                .filter((provider) => provider.category === category)
                .map((provider) => (
                  <div className="provider-order-item" key={provider.id}>
                    <GripVertical size={15} aria-hidden="true" />
                    <span>{provider.displayName}</span>
                    {provider.planType ? <small>{provider.planType}</small> : null}
                  </div>
                ))}
            </fieldset>
          ))}
        </div>
        <footer className="provider-order-footer">
          <button onClick={onClose}>Cancel</button>
          <button className="primary-button">Apply</button>
        </footer>
      </section>
    </div>
  );
}
