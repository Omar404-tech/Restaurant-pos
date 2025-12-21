// Utility functions

/**
 * Format number to Arabic locale
 */
export function formatNumber(num: number): string {
  return new Intl.NumberFormat('ar-EG').format(num)
}

/**
 * Format currency to Egyptian Pound
 */
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('ar-EG', {
    style: 'currency',
    currency: 'EGP',
  }).format(amount)
}

/**
 * Format date to Arabic locale
 */
export function formatDate(date: string | Date): string {
  return new Intl.DateTimeFormat('ar-EG', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(new Date(date))
}

/**
 * Format datetime to Arabic locale
 */
export function formatDateTime(date: string | Date): string {
  return new Intl.DateTimeFormat('ar-EG', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(date))
}

/**
 * Format time only
 */
export function formatTime(date: string | Date): string {
  return new Intl.DateTimeFormat('ar-EG', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(date))
}

/**
 * Get status color class
 */
export function getStatusColor(status: string): string {
  const colors: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-800',
    approved: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800',
    received: 'bg-blue-100 text-blue-800',
    active: 'bg-green-100 text-green-800',
    inactive: 'bg-gray-100 text-gray-800',
    new: 'bg-blue-100 text-blue-800',
    paid: 'bg-green-100 text-green-800',
    in_kitchen: 'bg-orange-100 text-orange-800',
    preparing: 'bg-yellow-100 text-yellow-800',
    ready: 'bg-green-100 text-green-800',
    delivered: 'bg-gray-100 text-gray-800',
    cancelled: 'bg-red-100 text-red-800',
  }
  return colors[status] || 'bg-gray-100 text-gray-800'
}

/**
 * Translate status to Arabic
 */
export function translateStatus(status: string): string {
  const translations: Record<string, string> = {
    pending: 'معلق',
    approved: 'موافق عليه',
    rejected: 'مرفوض',
    received: 'مستلم',
    active: 'نشط',
    inactive: 'غير نشط',
    new: 'جديد',
    paid: 'مدفوع',
    in_kitchen: 'في المطبخ',
    preparing: 'قيد التحضير',
    ready: 'جاهز',
    delivered: 'تم التسليم',
    cancelled: 'ملغي',
    draft: 'مسودة',
    completed: 'مكتمل',
  }
  return translations[status] || status
}

/**
 * Classnames helper
 */
export function cn(...classes: (string | undefined | null | false)[]): string {
  return classes.filter(Boolean).join(' ')
}

/**
 * Fix corrupted UTF-8 text - maps known corrupted strings to correct Arabic
 */
export function fixArabicEncoding(text: string | null | undefined): string {
  if (!text) return ''
  
  // Direct mapping for known corrupted values
  const knownMappings: Record<string, string> = {
    'Ù…Ø¯ÙŠØ± Ø§Ù„Ù†Ø¸Ø§Ù…': 'مدير النظام',
    'Ø£Ø­Ù…Ø¯ Ù…Ø­Ù…Ø¯': 'أحمد محمد',
    'Ù…Ø­Ù…Ø¯ Ø¹Ù„ÙŠ': 'محمد علي',
    'Ø³Ø§Ø±Ø© Ø£Ø­Ù…Ø¯': 'سارة أحمد',
    'Ø­Ø³Ù† Ø¥Ø¨Ø±Ø§Ù‡ÙŠÙ…': 'حسن إبراهيم',
    'Ù…Ø¯ÙŠØ± Ø§Ù„Ù…Ø®Ø²Ù†': 'مدير المخزن',
    'Ù…Ø´Ø±Ù Ø§Ù„ÙØ±Ø¹': 'مشرف الفرع',
    'ÙƒØ§Ø´ÙŠØ±': 'كاشير',
    'Ø´ÙŠÙ': 'شيف',
    'Ù…Ø¯ÙŠØ± Ø§Ù„Ù…Ø´ØªØ±ÙŠØ§Øª': 'مدير المشتريات',
  }
  
  // Check if text matches a known corrupted value
  if (knownMappings[text]) {
    return knownMappings[text]
  }
  
  // Try to decode if it looks corrupted
  try {
    if (/[\u00C0-\u00FF]{2,}/.test(text)) {
      const bytes = new Uint8Array(text.length)
      for (let i = 0; i < text.length; i++) {
        bytes[i] = text.charCodeAt(i)
      }
      return new TextDecoder('utf-8').decode(bytes)
    }
  } catch {
    // Ignore decoding errors
  }
  
  return text
}
