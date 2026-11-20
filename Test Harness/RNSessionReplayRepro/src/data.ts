// Mock catalog shaped like the Levi's app screens attached to NR-652282.

export type Product = {
  id: string;
  name: string;
  price: string;
  listPrice?: string;
  outOfStock?: boolean;
  images: string[];
  swatches: string[];
};

const img = (id: number) => `https://picsum.photos/id/${id}/600/800`;

export const PRODUCTS: Product[] = [
  {
    id: 'beanie',
    name: 'Backpatch Beanie',
    price: '$18.98',
    listPrice: '$25.00',
    outOfStock: true,
    images: [img(1005), img(1011), img(1012)],
    swatches: ['#E8418C', '#1C1C1C', '#1F2A55', '#B8A99A', '#C98A2B', '#4B4A2E', '#DCE3EE'],
  },
  {
    id: 'jeans',
    name: "501® Original Fit Men's Jeans",
    price: '$79.50',
    images: [img(1025), img(1027), img(1035), img(1036), img(1040)],
    swatches: ['#2B3F5C', '#4A6A8F', '#111111'],
  },
  {
    id: 'trucker',
    name: 'Sherpa Trucker Jacket',
    price: '$128.00',
    listPrice: '$148.00',
    images: [img(1062), img(1074), img(1084)],
    swatches: ['#5A4632', '#2E2E2E'],
  },
  {
    id: 'tee',
    name: 'Classic Housemark Tee',
    price: '$25.00',
    images: [img(1050), img(1059)],
    swatches: ['#FFFFFF', '#C8102E', '#111111', '#7A8B99'],
  },
];

export const CATEGORIES = ['New', 'Men', 'Women', 'Kids', 'Sale'];
