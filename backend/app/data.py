from typing import List

from app.schemas import NewsItem

MOCK_NEWS: List[NewsItem] = [
    NewsItem(
        id="20260528-001",
        title="基础模型提升多模态科学推理能力",
        abstract=(
            "我们构建了一个多模态科学推理基准，并提出一种结合符号工具使用"
            "与视觉语言推理的方法来提升准确率。"
        ),
        ai_summary=(
            "工具增强的多模态推理显著提升了科学基准任务的准确率。"
        ),
        authors=["A. Chen", "B. Kumar", "L. Wang"],
        published_date="2026-05-28",
        category="计算机科学",
        doi="10.1000/mock.2026.001",
        source_url="https://example.org/paper/20260528-001",
    ),
    NewsItem(
        id="20260528-002",
        title="单细胞图谱揭示动态免疫细胞状态",
        abstract=(
            "该研究构建了跨组织单细胞图谱，并识别出与炎症消退相关的"
            "瞬时免疫状态。"
        ),
        ai_summary=(
            "单细胞图谱揭示了炎症消退过程中的瞬时免疫状态。"
        ),
        authors=["Y. Li", "M. Patel"],
        published_date="2026-05-28",
        category="生物学",
        doi="10.1000/mock.2026.002",
        source_url="https://example.org/paper/20260528-002",
    ),
    NewsItem(
        id="20260528-003",
        title="高熵钙钛矿用于稳定太阳能转换",
        abstract=(
            "我们设计了高熵钙钛矿组分，可抑制相分离并在热应力下"
            "延长器件寿命。"
        ),
        ai_summary=(
            "高熵钙钛矿能够抑制相分离并提升热稳定性。"
        ),
        authors=["R. Singh", "J. Zhao", "E. Rossi"],
        published_date="2026-05-28",
        category="材料科学",
        doi="10.1000/mock.2026.003",
        source_url="https://example.org/paper/20260528-003",
    ),
]
