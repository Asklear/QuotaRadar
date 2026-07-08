import { ChevronDown, ChevronUp, GripVertical, RotateCcw, X } from "lucide-react";
import { formatProviderPlanType, useTranslate } from "../i18n";
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

function buildEffectiveProviderOrder(providerOrder: string[] | undefined) {
  const providerIds = providerRegistry.map((provider) => provider.id);
  const providerIdSet = new Set(providerIds);
  const effectiveProviderOrder: string[] = [];

  for (const providerId of providerOrder ?? []) {
    if (providerIdSet.has(providerId) && !effectiveProviderOrder.includes(providerId)) {
      effectiveProviderOrder.push(providerId);
    }
  }

  for (const providerId of providerIds) {
    if (!effectiveProviderOrder.includes(providerId)) {
      effectiveProviderOrder.push(providerId);
    }
  }

  return effectiveProviderOrder;
}

function orderIndex(effectiveProviderOrder: string[], providerId: string) {
  const index = effectiveProviderOrder.indexOf(providerId);
  return index === -1 ? Number.MAX_SAFE_INTEGER : index;
}

export function ProviderOrderDialog({
  open,
  providerOrder,
  onClose,
  onMoveProvider,
  onResetProviderOrder,
}: ProviderOrderDialogProps) {
  const t = useTranslate();

  if (!open) {
    return null;
  }

  const effectiveProviderOrder = buildEffectiveProviderOrder(providerOrder);
  const orderedProviders = [...providerRegistry].sort((left, right) => {
    return orderIndex(effectiveProviderOrder, left.id) - orderIndex(effectiveProviderOrder, right.id);
  });

  function moveInsideCategory(providerId: string, category: ProviderCategory, direction: -1 | 1) {
    const categoryProviders = orderedProviders.filter((provider) => provider.category === category);
    const categoryIndex = categoryProviders.findIndex((provider) => provider.id === providerId);
    const target = categoryProviders[categoryIndex + direction];

    if (!target) {
      return;
    }

    void onMoveProvider?.(providerId, effectiveProviderOrder.indexOf(target.id));
  }

  return (
    <div className="dialog-backdrop">
      <section className="provider-order-dialog" role="dialog" aria-label={t("providerOrder.title")}>
        <header className="provider-order-header">
          <div>
            <h2>{t("providerOrder.title")}</h2>
            <p>{t("providerOrder.description")}</p>
          </div>
          <div className="provider-order-header-actions">
            <button aria-label={t("providerOrder.reset")} onClick={() => void onResetProviderOrder?.()}>
              <RotateCcw size={15} />
            </button>
            <button aria-label={t("providerOrder.close")} onClick={onClose}>
              <X size={16} />
            </button>
          </div>
        </header>
        <div className="provider-order-body">
          {categories.map((category) => (
            <fieldset className="provider-order-group" key={category} aria-label={category === "AI Search" ? t("category.aiSearch") : t("category.llm")}>
              <legend>{category === "AI Search" ? t("category.aiSearch") : t("category.llm")}</legend>
              {orderedProviders
                .filter((provider) => provider.category === category)
                .map((provider) => (
                  <div className="provider-order-item" key={provider.id}>
                    <GripVertical size={15} aria-hidden="true" />
                    <span>{provider.displayName}</span>
                    {provider.planType ? <small>{formatProviderPlanType(provider.planType, t)}</small> : null}
                    <div className="provider-order-move-actions">
                      <button
                        aria-label={t("providerOrder.moveUp").replace("{provider}", provider.displayName)}
                        onClick={() => moveInsideCategory(provider.id, category, -1)}
                      >
                        <ChevronUp size={14} />
                      </button>
                      <button
                        aria-label={t("providerOrder.moveDown").replace("{provider}", provider.displayName)}
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
          <button onClick={onClose}>{t("common.done")}</button>
        </footer>
      </section>
    </div>
  );
}
