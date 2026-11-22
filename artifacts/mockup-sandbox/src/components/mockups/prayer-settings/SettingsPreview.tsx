import {
  CalendarDays,
  Clock3,
  Download,
  MapPin,
  Plus,
  Save,
  Settings2,
  Upload,
} from "lucide-react";
import type { ReactNode } from "react";

import "./settings-preview.css";

const prayers = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"];

function SectionTitle({
  icon,
  children,
}: {
  icon: ReactNode;
  children: ReactNode;
}) {
  return (
    <h2 className="settings-section-title">
      <span className="settings-section-icon">{icon}</span>
      {children}
    </h2>
  );
}

function EmptyMinutes({ label }: { label: string }) {
  return (
    <div className="minutes-row">
      <span>{label}</span>
      <div className="minutes-input">
        <span className="minutes-placeholder">بالدقائق</span>
        <span className="minutes-suffix">دقيقة</span>
      </div>
    </div>
  );
}

function SaveButton({ children }: { children: ReactNode }) {
  return (
    <button className="settings-save" type="button">
      <Save size={18} />
      {children}
    </button>
  );
}

export function SettingsPreview() {
  return (
    <main className="settings-preview" dir="rtl" lang="ar">
      <header className="settings-topbar">
        <div className="settings-brand">
          <div className="settings-brand-mark">
            <Settings2 size={25} />
          </div>
          <div>
            <span className="settings-eyebrow">إدارة شاشة المسجد</span>
            <h1>إعدادات مواقيت الصلاة</h1>
          </div>
        </div>
        <span className="settings-device-pill">وضع العرض الأفقي</span>
      </header>

      <div className="settings-content">
        <section className="settings-card names-card">
          <SectionTitle icon={<Settings2 size={19} />}>اسم المسجد</SectionTitle>
          <div className="name-fields">
            <label className="settings-field">
              <span>اسم التطبيق</span>
              <div className="field-input filled">مواقيت الصلاة</div>
              <small>يظهر هذا الاسم إذا لم يُكتب اسم مسجد.</small>
            </label>
            <label className="settings-field">
              <span>اسم المسجد</span>
              <div className="field-input empty">اكتب اسم المسجد</div>
              <small>يظهر بدل «مواقيت الصلاة» في الواجهة الرئيسية.</small>
            </label>
          </div>
          <SaveButton>حفظ الاسم</SaveButton>
        </section>

        <section className="settings-card region-card">
          <SectionTitle icon={<MapPin size={19} />}>
            مواقيت الصلاة حسب المنطقة
          </SectionTitle>
          <div className="region-controls">
            <div className="field-input region-select">
              <span className="field-hint">اختر المنطقة</span>
              <span className="chevron">⌄</span>
            </div>
            <button className="settings-save region-save" type="button">
              <Save size={18} />
              حفظ المنطقة الحالية
            </button>
          </div>
          <div className="region-tools">
            <div className="region-action">
              <Plus size={18} />
              <span>إضافة منطقة جديدة</span>
            </div>
            <button className="settings-outline" type="button">
              <Upload size={17} />
              استيراد مواقيت JSON
            </button>
            <button className="settings-outline" type="button">
              <Download size={17} />
              تصدير نسخة احتياطية
            </button>
          </div>
          <p className="settings-note">
            أضف المنطقة ثم حمّل ملف مواقيتها السنوي؛ ستبقى القائمة فارغة حتى
            استيراد الجداول.
          </p>
        </section>

        <section className="settings-card duration-card">
          <SectionTitle icon={<Clock3 size={19} />}>
            الوقت المتبقي لإقامة الصلاة
          </SectionTitle>
          <p className="section-description">
            أدخل عدد الدقائق بين الأذان والإقامة. اترك الحقل فارغًا إلى أن تحدد
            الإدارة المدة.
          </p>
          <div className="duration-grid">
            {prayers.map((prayer) => (
              <EmptyMinutes key={`iqama-${prayer}`} label={prayer} />
            ))}
          </div>
          <SaveButton>حفظ مدد الإقامة</SaveButton>
        </section>

        <section className="settings-card duration-card">
          <SectionTitle icon={<Clock3 size={19} />}>وقت الصلاة</SectionTitle>
          <p className="section-description">
            المدة الكاملة تشمل دقيقة «الصلاة قائمة» ثم الشاشة السوداء.
          </p>
          <div className="duration-grid">
            {prayers.map((prayer) => (
              <EmptyMinutes key={`prayer-${prayer}`} label={prayer} />
            ))}
          </div>
          <SaveButton>حفظ مدد الصلاة</SaveButton>
        </section>

        <section className="settings-card bottom-card">
          <SectionTitle icon={<Clock3 size={19} />}>
            أذكار بعد الصلاة وخطبة الجمعة
          </SectionTitle>
          <div className="two-minute-fields">
            <EmptyMinutes label="مدة عرض أذكار الصلاة" />
            <EmptyMinutes label="مدة خطبة الجمعة" />
          </div>
          <SaveButton>حفظ مدد الأذكار والخطبة</SaveButton>
        </section>

        <section className="settings-card bottom-card hijri-card">
          <SectionTitle icon={<CalendarDays size={19} />}>
            تعديل التاريخ الهجري يدويًا
          </SectionTitle>
          <p className="section-description">
            اختر اليوم والشهر الصحيحين، ويستمر التصحيح تلقائيًا في الأيام
            التالية.
          </p>
          <div className="hijri-fields">
            <div className="field-input"><span className="field-hint">اليوم</span><span className="chevron">⌄</span></div>
            <div className="field-input"><span className="field-hint">الشهر</span><span className="chevron">⌄</span></div>
          </div>
          <div className="hijri-actions">
            <SaveButton>حفظ التاريخ</SaveButton>
            <button className="settings-outline" type="button">الحساب التلقائي</button>
          </div>
        </section>
      </div>
      <footer className="settings-footer">
        <span>مواقيت الصلاة</span>
        <span>إعدادات محفوظة على هذا الجهاز</span>
      </footer>
    </main>
  );
}
