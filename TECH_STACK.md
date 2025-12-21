# Technology Stack - Restaurant Management System

## Overview

This is a modern web application for restaurant management built with a React frontend and Supabase backend.

---

## Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| **React** | 18.x | UI Library |
| **TypeScript** | 5.x | Type-safe JavaScript |
| **Vite** | 5.x | Build tool & dev server |
| **React Router** | 6.x | Client-side routing |
| **Tailwind CSS** | 3.x | Utility-first CSS framework |
| **Lucide React** | Latest | Icon library |

### Frontend Structure
```
restaurant-react/
├── src/
│   ├── components/     # Reusable UI components
│   │   ├── layout/     # Layout components (Navbar, Sidebar, MainLayout)
│   │   └── ui/         # UI components (StatCard, etc.)
│   ├── contexts/       # React contexts (AuthContext)
│   ├── hooks/          # Custom hooks (useCart, useRealtime)
│   ├── lib/            # Utilities (supabase client, utils)
│   ├── pages/          # Page components
│   │   ├── auth/       # Login page
│   │   ├── branches/   # Branch management
│   │   ├── damages/    # Damage records
│   │   ├── dashboard/  # Dashboard
│   │   ├── inventory/  # Inventory management
│   │   ├── pos/        # Point of Sale
│   │   ├── purchase/   # Purchase management
│   │   ├── reports/    # Reports
│   │   ├── returns/    # Returns management
│   │   ├── settings/   # Settings
│   │   ├── suppliers/  # Supplier management
│   │   ├── transfers/  # Transfer management
│   │   └── users/      # User management
│   ├── services/       # API service layers
│   └── types/          # TypeScript type definitions
```

---

## Backend / Database

| Technology | Purpose |
|------------|---------|
| **Supabase** | Backend-as-a-Service (BaaS) |
| **PostgreSQL** | Relational database (hosted by Supabase) |
| **Supabase JS Client** | Database queries & real-time subscriptions |

### Supabase Features Used
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Authentication**: Custom auth using users table
- **Real-time**: Subscriptions for live updates
- **Storage**: For file uploads (images)

---

## Database Schema

### Main Tables (50+ tables)

| Category | Tables |
|----------|--------|
| **Core** | branches, users, roles, categories, units |
| **Inventory** | items, inventory, inventory_transactions, inventory_batches |
| **Suppliers** | suppliers, supplies, supply_items, supplier_payments |
| **Transfers** | transfers, transfer_items |
| **Damages** | damages, damage_reasons |
| **Returns** | supplier_returns, branch_returns, branch_return_items |
| **Orders** | orders, order_items |
| **Menu** | menu_items, menu_categories, menu_item_ingredients |
| **Purchase** | purchase_requests, purchase_request_items, purchase_orders, purchase_order_items |
| **Inventory Count** | daily_inventory_counts, daily_inventory_count_items |
| **Settings** | system_settings, branch_settings, alert_settings |
| **Audit** | audit_logs, notifications, user_sessions |

---

## Key Libraries & Dependencies

### Frontend (package.json)
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.x",
    "@supabase/supabase-js": "^2.x",
    "lucide-react": "latest"
  },
  "devDependencies": {
    "typescript": "^5.x",
    "vite": "^5.x",
    "tailwindcss": "^3.x",
    "@types/react": "^18.x"
  }
}
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Frontend                            │
│  ┌─────────────────────────────────────────────────┐    │
│  │              React + TypeScript                  │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────────────┐   │    │
│  │  │  Pages  │ │Components│ │    Services     │   │    │
│  │  └────┬────┘ └────┬────┘ └────────┬────────┘   │    │
│  │       │           │               │            │    │
│  │       └───────────┴───────────────┘            │    │
│  │                    │                           │    │
│  │           ┌────────▼────────┐                  │    │
│  │           │ Supabase Client │                  │    │
│  │           └────────┬────────┘                  │    │
│  └────────────────────┼─────────────────────────────┘    │
└───────────────────────┼─────────────────────────────────┘
                        │ HTTPS
                        ▼
┌─────────────────────────────────────────────────────────┐
│                     Supabase                             │
│  ┌─────────────────────────────────────────────────┐    │
│  │                 PostgreSQL                       │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────────────┐   │    │
│  │  │ Tables  │ │  Views  │ │    Functions    │   │    │
│  │  └─────────┘ └─────────┘ └─────────────────┘   │    │
│  └─────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Real-time Engine                    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## Development Setup

### Prerequisites
- Node.js 18+
- npm or yarn

### Running the Application
```bash
# Navigate to frontend directory
cd restaurant-react

# Install dependencies
npm install

# Start development server
npm run dev

# Application runs on http://localhost:5173
```

### Environment Variables (.env)
```
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

---

## Features

| Feature | Technology Used |
|---------|-----------------|
| Authentication | Custom auth with Supabase + localStorage |
| Role-based Access | React Context + Route guards |
| Real-time Updates | Supabase Realtime subscriptions |
| Arabic RTL Support | Tailwind CSS RTL utilities |
| Responsive Design | Tailwind CSS responsive classes |
| Form Validation | HTML5 + Custom validation |
| State Management | React useState + useContext |
| API Layer | Service pattern with Supabase client |

---

## Deployment Options

| Platform | Suitable For |
|----------|--------------|
| **Vercel** | Frontend hosting (recommended) |
| **Netlify** | Frontend hosting |
| **Supabase** | Database already hosted |
| **Docker** | Self-hosted deployment |

---

## Security Features

- Row Level Security (RLS) on database
- Role-based access control
- Session management with localStorage
- Input validation and sanitization
- HTTPS encryption (Supabase)
