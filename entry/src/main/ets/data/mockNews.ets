import { NewsCategory, ResearchNews } from '../models/ResearchNews';

export const MOCK_NEWS: ResearchNews[] = [
  {
    id: '20260528-001',
    title: '基础模型提升多模态科学推理能力',
    abstract: '我们构建了一个多模态科学推理基准，并提出一种结合符号工具使用与视觉语言推理的方法来提升准确率。',
    aiSummary: '工具增强的多模态推理显著提升了科学基准任务的准确率。',
    authors: ['A. Chen', 'B. Kumar', 'L. Wang'],
    publishedDate: '2026-05-28',
    category: NewsCategory.ComputerScience,
    doi: '10.1000/mock.2026.001',
    sourceUrl: 'https://example.org/paper/20260528-001'
  },
  {
    id: '20260528-002',
    title: '单细胞图谱揭示动态免疫细胞状态',
    abstract: '该研究构建了跨组织单细胞图谱，并识别出与炎症消退相关的瞬时免疫状态。',
    aiSummary: '单细胞图谱揭示了炎症消退过程中的瞬时免疫状态。',
    authors: ['Y. Li', 'M. Patel'],
    publishedDate: '2026-05-28',
    category: NewsCategory.Biology,
    doi: '10.1000/mock.2026.002',
    sourceUrl: 'https://example.org/paper/20260528-002'
  },
  {
    id: '20260528-003',
    title: '高熵钙钛矿用于稳定太阳能转换',
    abstract: '我们设计了高熵钙钛矿组分，可抑制相分离并在热应力下延长器件寿命。',
    aiSummary: '高熵钙钛矿能够抑制相分离并提升热稳定性。',
    authors: ['R. Singh', 'J. Zhao', 'E. Rossi'],
    publishedDate: '2026-05-28',
    category: NewsCategory.Materials,
    doi: '10.1000/mock.2026.003',
    sourceUrl: 'https://example.org/paper/20260528-003'
  }
];
