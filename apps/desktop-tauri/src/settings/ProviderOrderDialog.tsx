import { ChevronDown, ChevronUp, GripVertical, RotateCcw, X } from "lucide-react";
import { providerRegistry } from "../shared/mockData";
import type { ProviderCategory } from "../shared/types";

interface ProviderOrderDialogProps {
  open: boolean;
  providerOrder?: string[];
  onClose: () => void;
  onMoveProvider?: (providerId: string, toIndex: number) => void | Promise<void>;
  onResetProviderOrder?: () => void | Promise<void>;
}

const categories: ProviderCategory[] = ["AI Search", "LLM"];

function orderIndex(providerOrder: string[] | undefined, providerId: string) {
  const index = providerOrder?.indexOf(providerId) ?? -1;
  return index === -1 ? Number.MAX_SAFE_INTEGER : index;
}

export function ProviderOrderDialog({
  open,
  providerOrder,
  onClose,
  onMoveProvider,
  onResetProviderOrder,
}: ProviderOrderDialogProps) {
  if (!open) {
    return null;
  }

  const orderedProviders = [...providerRegistry].sort((left, right) => {
    return orderIndex(providerOrder, left.id) - orderIndex(providerOrder, right.id);
  });

  function moveInsideCategory(providerId: string, category: ProviderCategory, direction: -1 | 1) {
    const categoryProviders = orderedProviders.filter((provider) => provider.category === category);
    const categoryIndex = categoryProviders.findIndex((provider) => provider.id === providerId);
    const target = categoryProviders[categoryIndex + direction];

    if (!target || !providerOrder) {
      return;
    }

    void onMoveProvider?.(providerId, providerOrder.indexOf(target.id));
  }

  return (
    <div className="dialog-backdrop">
      <section className="provider-order-dialog" role="dialog" aria-label="Provider order">
        <header className="provider-order-header">
          <div>
            <h2>Provider order</h2>
            <p>Adjust the shared order used by monitoring, credentials, diagnostics, and tray views.</p>
          </div>
          <div className="provider-order-header-actions">
            <button aria-label="Reset provider order" onClick={() => void onResetProviderOrder?.()}>
              <RotateCcw size={15} />
            </button>
            <button aria-label="Close provider order" onClick={onClose}>
              <X size={16} />
            </button>
          </div>
        </header>
        <div className="provider-order-body">
          {categories.map((category) => (
            <fieldset className="provider-order-group" key={category} aria-label={category}>
              <legend>{category}</legend>
              {orderedProviders
                .filter((provider) => provider.category === category)
                .map((provider) => (
                  <div className="provider-order-item" key={provider.id}>
                    <GripVertical size={15} aria-hidden="true" />
                    <span>{provider.displayName}</span>
                    {provider.planType ? <small>{provider.planType}</small> : null}
                    <div className="provider-order-move-actions">
                      <button
                        aria-label={`Move ${provider.displayName} up`}
                        onClick={() => moveInsideCategory(provider.id, category, -1)}
                      >
                        <ChevronUp size={14} />
                      </button>
                      <button
                        aria-label={`Move ${provider.displayName} down`}
                        onClick={() => moveInsideCategory(provider.id, category, 1)}
                      >
                        <ChevronDown size={14} />
                      </button>
                    </div>
                  </div>
                ))}
            </fieldset>
          ))}
        </div>
        <footer className="provider-order-footer">
          <button onClick={onClose}>Done</button>
        </footer>
      </section>
    </div>
  );
}
