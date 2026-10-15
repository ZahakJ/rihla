"""Practice file for lesson 7b: a tiny stock store.

Fold it, outline it, search it, replace in it. Nothing runs it.
"""
from dataclasses import dataclass, field


@dataclass
class Item:
    sku: str
    name: str
    quantity: int = 0
    price: float = 0.0


@dataclass
class Store:
    items: dict[str, Item] = field(default_factory=dict)

    def add(self, item: Item) -> None:
        if item.sku in self.items:
            self.items[item.sku].quantity += item.quantity
        else:
            self.items[item.sku] = item

    def remove(self, sku: str, count: int = 1) -> Item:
        item = self.items[sku]
        if count > item.quantity:
            raise ValueError(f"only {item.quantity} of {sku} left")
        item.quantity -= count
        return item

    def value(self) -> float:
        return sum(i.quantity * i.price for i in self.items.values())

    def low_stock(self, threshold: int = 5) -> list[Item]:
        return [i for i in self.items.values() if i.quantity < threshold]


def report(store: Store) -> str:
    lines = [f"{len(store.items)} items, worth {store.value():.2f}"]
    for item in store.low_stock():
        lines.append(f"  low: {item.name} ({item.quantity})")
    return "\n".join(lines)
