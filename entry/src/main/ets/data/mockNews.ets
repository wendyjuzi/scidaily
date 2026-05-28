import { NewsCategory, ResearchNews } from '../models/ResearchNews';

export const MOCK_NEWS: ResearchNews[] = [
  {
    id: '20260528-001',
    title: 'Foundation Models Improve Multi-Modal Scientific Reasoning',
    abstract: 'We propose a benchmark for multi-modal scientific reasoning and present a model that improves accuracy by combining symbolic tool use with vision-language reasoning.',
    aiSummary: 'Tool-augmented multi-modal reasoning significantly improves accuracy on science benchmarks.',
    authors: ['A. Chen', 'B. Kumar', 'L. Wang'],
    publishedDate: '2026-05-28',
    category: NewsCategory.ComputerScience,
    doi: '10.1000/mock.2026.001',
    sourceUrl: 'https://example.org/paper/20260528-001'
  },
  {
    id: '20260528-002',
    title: 'Single-Cell Atlas Reveals Dynamic Immune Cell States',
    abstract: 'This study constructs a cross-tissue single-cell atlas and identifies transient immune states associated with inflammation resolution.',
    aiSummary: 'A single-cell atlas reveals transient immune states during inflammation resolution.',
    authors: ['Y. Li', 'M. Patel'],
    publishedDate: '2026-05-28',
    category: NewsCategory.Biology,
    doi: '10.1000/mock.2026.002',
    sourceUrl: 'https://example.org/paper/20260528-002'
  },
  {
    id: '20260528-003',
    title: 'High-Entropy Perovskites for Stable Solar Conversion',
    abstract: 'We design high-entropy perovskite compositions that suppress phase segregation and extend operational lifetime under thermal stress.',
    aiSummary: 'High-entropy perovskites suppress phase segregation and improve thermal stability.',
    authors: ['R. Singh', 'J. Zhao', 'E. Rossi'],
    publishedDate: '2026-05-28',
    category: NewsCategory.Materials,
    doi: '10.1000/mock.2026.003',
    sourceUrl: 'https://example.org/paper/20260528-003'
  }
];
