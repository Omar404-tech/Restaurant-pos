/**
 * Restaurant Inventory System - Main JavaScript
 */

document.addEventListener('DOMContentLoaded', function() {
    // Initialize tooltips
    var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });

    // Auto-hide alerts after 5 seconds
    setTimeout(function() {
        var alerts = document.querySelectorAll('.alert:not(.alert-permanent)');
        alerts.forEach(function(alert) {
            var bsAlert = new bootstrap.Alert(alert);
            bsAlert.close();
        });
    }, 5000);

    // Confirm delete actions
    document.querySelectorAll('[data-confirm]').forEach(function(element) {
        element.addEventListener('click', function(e) {
            if (!confirm(this.dataset.confirm || 'هل أنت متأكد؟')) {
                e.preventDefault();
            }
        });
    });

    // Mobile sidebar toggle
    var sidebarToggle = document.getElementById('sidebarToggle');
    if (sidebarToggle) {
        sidebarToggle.addEventListener('click', function() {
            document.querySelector('.sidebar').classList.toggle('show');
        });
    }

    // Print functionality
    document.querySelectorAll('[data-print]').forEach(function(btn) {
        btn.addEventListener('click', function() {
            window.print();
        });
    });

    // Number formatting for currency inputs
    document.querySelectorAll('.currency-input').forEach(function(input) {
        input.addEventListener('blur', function() {
            var value = parseFloat(this.value) || 0;
            this.value = value.toFixed(2);
        });
    });

    // Auto-calculate totals in forms
    function calculateTotal() {
        var qty = parseFloat(document.getElementById('quantity')?.value) || 0;
        var price = parseFloat(document.getElementById('unit_price')?.value) || 0;
        var totalField = document.getElementById('total_price');
        if (totalField) {
            totalField.value = (qty * price).toFixed(2);
        }
    }

    document.getElementById('quantity')?.addEventListener('input', calculateTotal);
    document.getElementById('unit_price')?.addEventListener('input', calculateTotal);

    // Search functionality with debounce
    var searchInput = document.getElementById('searchInput');
    if (searchInput) {
        var timeout = null;
        searchInput.addEventListener('input', function() {
            clearTimeout(timeout);
            timeout = setTimeout(function() {
                document.getElementById('searchForm')?.submit();
            }, 500);
        });
    }

    // Table row click to navigate
    document.querySelectorAll('tr[data-href]').forEach(function(row) {
        row.style.cursor = 'pointer';
        row.addEventListener('click', function() {
            window.location.href = this.dataset.href;
        });
    });

    // Form validation styling
    document.querySelectorAll('form').forEach(function(form) {
        form.addEventListener('submit', function(e) {
            if (!form.checkValidity()) {
                e.preventDefault();
                e.stopPropagation();
            }
            form.classList.add('was-validated');
        });
    });

    // Dynamic select2-like search for selects
    document.querySelectorAll('select.searchable').forEach(function(select) {
        // Add search functionality to large selects
        if (select.options.length > 10) {
            var wrapper = document.createElement('div');
            wrapper.className = 'position-relative';
            select.parentNode.insertBefore(wrapper, select);
            wrapper.appendChild(select);
        }
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', function(e) {
        // Ctrl+S to save forms
        if (e.ctrlKey && e.key === 's') {
            e.preventDefault();
            var form = document.querySelector('form');
            if (form) form.submit();
        }
        
        // Escape to go back
        if (e.key === 'Escape') {
            var backBtn = document.querySelector('a[href*="list"], .btn-secondary[href]');
            if (backBtn) window.location.href = backBtn.href;
        }
    });

    // Loading state for buttons
    document.querySelectorAll('form').forEach(function(form) {
        form.addEventListener('submit', function() {
            var submitBtn = form.querySelector('button[type="submit"]');
            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>جاري الحفظ...';
            }
        });
    });

    // Notification badge update
    function updateNotifications() {
        fetch('/api/accounts/notifications/?unread=true')
            .then(response => response.json())
            .then(data => {
                var badge = document.getElementById('notificationBadge');
                if (badge && data.count > 0) {
                    badge.textContent = data.count;
                    badge.style.display = 'inline';
                }
            })
            .catch(() => {});
    }
    
    // Update notifications every minute
    setInterval(updateNotifications, 60000);

    console.log('Restaurant Inventory System initialized');
});

// Utility functions
function formatCurrency(amount) {
    return parseFloat(amount).toFixed(2) + ' ج.م';
}

function formatDate(dateString) {
    var date = new Date(dateString);
    return date.toLocaleDateString('ar-EG');
}

function showToast(message, type = 'success') {
    var toast = document.createElement('div');
    toast.className = `alert alert-${type} position-fixed`;
    toast.style.cssText = 'top: 80px; left: 20px; z-index: 9999; min-width: 300px;';
    toast.innerHTML = `
        <i class="fas fa-${type === 'success' ? 'check-circle' : 'exclamation-circle'} me-2"></i>
        ${message}
    `;
    document.body.appendChild(toast);
    
    setTimeout(function() {
        toast.remove();
    }, 3000);
}

// Export for use in other scripts
window.RestaurantSystem = {
    formatCurrency,
    formatDate,
    showToast
};
