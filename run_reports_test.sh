#!/bin/bash

# ============================================================================
# سكريبت تشغيل اختبار شامل للتقارير
# ============================================================================

echo "============================================================================"
echo "🧪 بدء اختبار شامل لجميع التقارير"
echo "============================================================================"
echo ""

# الألوان
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. اختبار Python (Django)
echo "📊 تشغيل اختبار Python..."
echo "----------------------------------------"
if python tests/test_reports.py; then
    echo -e "${GREEN}✅ اختبار Python نجح${NC}"
else
    echo -e "${RED}❌ اختبار Python فشل${NC}"
fi
echo ""

# 2. اختبار SQL (إذا كان متاح)
echo "🗄️  تشغيل اختبار SQL..."
echo "----------------------------------------"
if command -v psql &> /dev/null; then
    # قراءة بيانات الاتصال من .env
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi
    
    # تشغيل اختبار SQL
    psql "$DATABASE_URL" -f database/test_reports_validation.sql
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ اختبار SQL نجح${NC}"
    else
        echo -e "${RED}❌ اختبار SQL فشل${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  psql غير متاح، تخطي اختبار SQL${NC}"
fi
echo ""

# 3. إنشاء تقرير HTML (اختياري)
echo "📄 إنشاء تقرير HTML..."
echo "----------------------------------------"
if command -v pandoc &> /dev/null; then
    pandoc REPORTS_TEST_RESULTS.md -o REPORTS_TEST_RESULTS.html --standalone --css=style.css
    echo -e "${GREEN}✅ تم إنشاء تقرير HTML${NC}"
else
    echo -e "${YELLOW}⚠️  pandoc غير متاح، تخطي إنشاء HTML${NC}"
fi
echo ""

# 4. عرض الملخص
echo "============================================================================"
echo "📊 ملخص الاختبار"
echo "============================================================================"
echo ""
echo "✅ تم إنشاء الملفات التالية:"
echo "  - tests/test_reports.py (سكريبت اختبار Python)"
echo "  - database/test_reports_validation.sql (سكريبت اختبار SQL)"
echo "  - REPORTS_TEST_GUIDE.md (دليل الاختبار)"
echo "  - REPORTS_TEST_RESULTS.md (نتائج الاختبار)"
echo ""
echo "📖 لقراءة النتائج الكاملة:"
echo "  cat REPORTS_TEST_RESULTS.md"
echo ""
echo "🔧 لإصلاح المشاكل المكتشفة:"
echo "  راجع قسم 'سكريبتات الإصلاح' في REPORTS_TEST_RESULTS.md"
echo ""
echo "============================================================================"
