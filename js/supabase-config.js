/**
 * BAGS STORE - Supabase Configuration
 * =====================================
 * Configuration and initialization for Supabase client
 */

// Supabase Configuration
const SUPABASE_URL = 'https://wtxrezufftbrvgjwxmqe.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0eHJlenVmZnRicnZnand4bXFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3NDQ2OTIsImV4cCI6MjA5ODMyMDY5Mn0.H_mqVZD47APcme1Yc72Tnn0IqC2m3aMyUGJGbOWaq-g';

// Initialize Supabase Client (using different name to avoid conflict with CDN's window.supabase)
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

/**
 * Store Configuration
 */
const STORE_CONFIG = {
    name: 'Luxury Bags',
    nameAr: 'شنط فاخرة',
    currency: 'EGP',
    currencySymbol: 'ج.م',
    cartReservationMinutes: 30,
    freeShippingThreshold: 500,
    defaultShippingCost: 50
};

/**
 * API Endpoints Helper
 */
const API = {
    // Products
    async getProducts(options = {}) {
        let query = supabaseClient
            .from('products')
            .select(`
                *,
                category:categories(id, name, name_ar, slug),
                brand:brands(id, name, slug),
                images:product_images(id, image_url, is_primary, sort_order),
                colors:product_colors(id, color_name, color_name_ar, color_hex, quantity, reserved_quantity)
            `)
            .eq('is_active', true);

        if (options.category) {
            query = query.eq('categories.slug', options.category);
        }
        if (options.brand) {
            query = query.eq('brands.slug', options.brand);
        }
        if (options.featured) {
            query = query.eq('is_featured', true);
        }
        if (options.newArrivals) {
            query = query.eq('is_new_arrival', true);
        }
        if (options.limit) {
            query = query.limit(options.limit);
        }
        if (options.orderBy) {
            query = query.order(options.orderBy, { ascending: options.ascending ?? false });
        }

        const { data, error } = await query;
        if (error) throw error;
        return data;
    },

    async getProductBySlug(slug) {
        const { data, error } = await supabaseClient
            .from('products')
            .select(`
                *,
                category:categories(id, name, name_ar, slug),
                subcategory:subcategories(id, name, name_ar, slug),
                brand:brands(id, name, slug, logo_url),
                images:product_images(id, image_url, thumbnail_url, alt_text, is_primary, sort_order),
                colors:product_colors(id, color_name, color_name_ar, color_hex, color_image_url, quantity, reserved_quantity),
                attributes:product_attributes(id, attribute_name, attribute_value, sort_order),
                tags:product_tags(id, tag)
            `)
            .eq('slug', slug)
            .eq('is_active', true)
            .single();

        if (error) throw error;
        return data;
    },

    async getSaleProducts(limit = 12) {
        const { data, error } = await supabaseClient
            .from('sales')
            .select(`
                *,
                product:products(
                    *,
                    category:categories(id, name, name_ar, slug),
                    brand:brands(id, name, slug),
                    images:product_images(id, image_url, is_primary, sort_order),
                    colors:product_colors(id, color_name, color_hex, quantity, reserved_quantity)
                )
            `)
            .eq('is_active', true)
            .lte('start_date', new Date().toISOString())
            .or(`end_date.is.null,end_date.gt.${new Date().toISOString()}`)
            .limit(limit);

        if (error) throw error;
        return data;
    },

    // Categories
    async getCategories() {
        const { data, error } = await supabaseClient
            .from('categories')
            .select('*')
            .eq('is_active', true)
            .order('sort_order');

        if (error) throw error;
        return data;
    },

    // Brands
    async getBrands() {
        const { data, error } = await supabaseClient
            .from('brands')
            .select('*')
            .eq('is_active', true)
            .order('sort_order');

        if (error) throw error;
        return data;
    },

    // Cart
    async getCart() {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return [];

        const { data, error } = await supabaseClient
            .rpc('get_cart_details', { p_user_id: user.id });

        if (error) throw error;
        return data;
    },

    async addToCart(productId, colorId, quantity) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login to add items to cart');

        const { data, error } = await supabaseClient
            .rpc('add_to_cart', {
                p_user_id: user.id,
                p_product_id: productId,
                p_color_id: colorId,
                p_quantity: quantity
            });

        if (error) throw error;
        return data;
    },

    async updateCartQuantity(cartItemId, quantity) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login');

        const { data, error } = await supabaseClient
            .rpc('update_cart_quantity', {
                p_user_id: user.id,
                p_cart_item_id: cartItemId,
                p_new_quantity: quantity
            });

        if (error) throw error;
        return data;
    },

    async removeFromCart(cartItemId) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login');

        const { data, error } = await supabaseClient
            .rpc('remove_from_cart', {
                p_user_id: user.id,
                p_cart_item_id: cartItemId
            });

        if (error) throw error;
        return data;
    },

    // Orders
    async createOrder(addressId, paymentMethod, shippingMethodId, couponCode = null, notes = null) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login to place order');

        // Get cart items first
        const cart = await this.getCart();
        if (!cart || cart.length === 0) throw new Error('Cart is empty');

        // Get user profile for customer info
        const profile = await this.getProfile();

        // Get address for shipping info
        const { data: address } = await supabaseClient
            .from('addresses')
            .select('*')
            .eq('id', addressId)
            .single();

        // Calculate totals
        const subtotal = cart.reduce((sum, item) => sum + (item.line_total || item.quantity * item.unit_price), 0);
        const shippingCost = subtotal >= 500 ? 0 : 50;
        const total = subtotal + shippingCost;
        const totalItems = cart.length;
        const totalQuantity = cart.reduce((sum, item) => sum + item.quantity, 0);

        // Generate order number
        const orderNumber = 'ORD-' + new Date().toISOString().slice(0, 10).replace(/-/g, '') + '-' + Math.floor(Math.random() * 10000).toString().padStart(4, '0');

        // Create order with all required fields
        const { data: order, error: orderError } = await supabaseClient
            .from('orders')
            .insert({
                user_id: user.id,
                order_number: orderNumber,
                address_id: addressId,
                subtotal: subtotal,
                shipping_cost: shippingCost,
                total_amount: total,
                total_items: totalItems,
                total_quantity: totalQuantity,
                payment_method: paymentMethod,
                payment_status: 'pending',
                status: 'pending',
                // Required customer fields
                customer_name: address?.recipient_name || profile?.full_name || user.email.split('@')[0],
                customer_email: user.email,
                customer_phone: address?.phone || profile?.phone || 'N/A',
                // Optional shipping info from address
                shipping_governorate: address?.governorate,
                shipping_city: address?.city,
                shipping_address: address?.street_address,
                customer_notes: notes
            })
            .select()
            .single();

        if (orderError) throw orderError;

        // Create order items
        const orderItems = cart.map(item => ({
            order_id: order.id,
            product_id: item.product_id,
            color_id: item.color_id,
            product_name: item.product_name,
            color_name: item.color_name,
            quantity: item.quantity,
            unit_price: item.unit_price,
            total_price: item.line_total || item.quantity * item.unit_price
        }));

        const { error: itemsError } = await supabaseClient
            .from('order_items')
            .insert(orderItems);

        if (itemsError) throw itemsError;

        return order.id;
    },

    async clearCart() {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return;

        await supabaseClient
            .from('cart_items')
            .delete()
            .eq('user_id', user.id);
    },

    async getOrders() {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return [];

        const { data, error } = await supabaseClient
            .from('orders')
            .select(`
                *,
                items:order_items(*)
            `)
            .eq('user_id', user.id)
            .order('created_at', { ascending: false });

        if (error) throw error;
        return data;
    },

    async getOrderById(orderId) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login');

        const { data, error } = await supabaseClient
            .from('orders')
            .select(`
                *,
                items:order_items(*),
                status_history:order_status_history(*)
            `)
            .eq('id', orderId)
            .eq('user_id', user.id)
            .single();

        if (error) throw error;
        return data;
    },

    // Coupons
    async validateCoupon(code, subtotal, itemCount = 1) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login');

        const { data, error } = await supabaseClient
            .rpc('validate_coupon', {
                p_code: code,
                p_user_id: user.id,
                p_order_subtotal: subtotal,
                p_item_count: itemCount
            });

        if (error) throw error;
        return data[0];
    },

    // Reviews
    async getProductReviews(productId, page = 1, limit = 10, sortBy = 'newest') {
        const { data, error } = await supabaseClient
            .rpc('get_product_reviews', {
                p_product_id: productId,
                p_page: page,
                p_limit: limit,
                p_sort_by: sortBy
            });

        if (error) throw error;
        return data;
    },

    async getReviewStats(productId) {
        const { data, error } = await supabaseClient
            .rpc('get_review_stats', { p_product_id: productId });

        if (error) throw error;
        return data[0];
    },

    // Wishlist
    async getWishlist() {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return [];

        const { data, error } = await supabaseClient
            .from('wishlists')
            .select(`
                *,
                product:products(
                    *,
                    images:product_images(id, image_url, is_primary),
                    colors:product_colors(id, color_name, color_hex, quantity)
                )
            `)
            .eq('user_id', user.id)
            .order('created_at', { ascending: false });

        if (error) throw error;
        return data;
    },

    async addToWishlist(productId) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login');

        const { data, error } = await supabaseClient
            .from('wishlists')
            .upsert({ user_id: user.id, product_id: productId })
            .select();

        if (error) throw error;
        return data;
    },

    async removeFromWishlist(productId) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login');

        const { error } = await supabaseClient
            .from('wishlists')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', productId);

        if (error) throw error;
        return true;
    },

    // User Profile & Addresses
    async getProfile() {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return null;

        const { data, error } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single();

        if (error) throw error;
        return data;
    },

    async updateProfile(updates) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login');

        const { data, error } = await supabaseClient
            .from('profiles')
            .update(updates)
            .eq('id', user.id)
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    async getAddresses() {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return [];

        const { data, error } = await supabaseClient
            .from('addresses')
            .select('*')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .order('is_default', { ascending: false });

        if (error) throw error;
        return data;
    },

    async addAddress(address) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) throw new Error('Please login');

        const { data, error } = await supabaseClient
            .from('addresses')
            .insert({ ...address, user_id: user.id })
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Shipping Methods
    async getShippingMethods() {
        const { data, error } = await supabaseClient
            .from('shipping_methods')
            .select('*')
            .eq('is_active', true)
            .order('sort_order');

        if (error) throw error;
        return data;
    },

    // Site Settings & Content
    async getSettings() {
        const { data, error } = await supabaseClient
            .rpc('get_public_settings');

        if (error) throw error;
        return data;
    },

    async getBanners(position = 'hero') {
        const { data, error } = await supabaseClient
            .rpc('get_active_banners', { p_position: position });

        if (error) throw error;
        return data;
    },

    async getFAQ() {
        const { data, error } = await supabaseClient
            .from('faq')
            .select('*')
            .eq('is_active', true)
            .order('sort_order');

        if (error) throw error;
        return data;
    },

    async getPage(slug) {
        const { data, error } = await supabaseClient
            .from('static_pages')
            .select('*')
            .eq('slug', slug)
            .eq('is_active', true)
            .single();

        if (error) throw error;
        return data;
    },

    // Contact
    async submitContactForm(formData) {
        const { data, error } = await supabaseClient
            .from('contact_messages')
            .insert(formData)
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Newsletter
    async subscribeNewsletter(email, name = null) {
        const { data, error } = await supabaseClient
            .rpc('subscribe_newsletter', {
                p_email: email,
                p_name: name,
                p_source: 'website'
            });

        if (error) throw error;
        return data;
    },

    // Track product view
    async trackProductView(productId) {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return;

        await supabaseClient.rpc('track_product_view', {
            p_user_id: user.id,
            p_product_id: productId
        });
    }
};

/**
 * Authentication Helper
 */
const Auth = {
    async signUp(email, password, metadata = {}) {
        const { data, error } = await supabaseClient.auth.signUp({
            email,
            password,
            options: {
                data: metadata
            }
        });
        if (error) throw error;
        return data;
    },

    async signIn(email, password) {
        const { data, error } = await supabaseClient.auth.signInWithPassword({
            email,
            password
        });
        if (error) throw error;
        return data;
    },

    async signInWithGoogle() {
        const { data, error } = await supabaseClient.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo: window.location.origin
            }
        });
        if (error) throw error;
        return data;
    },

    async signOut() {
        const { error } = await supabaseClient.auth.signOut();
        if (error) throw error;
    },

    async getUser() {
        const { data: { user } } = await supabaseClient.auth.getUser();
        return user;
    },

    async getSession() {
        const { data: { session } } = await supabaseClient.auth.getSession();
        return session;
    },

    async resetPassword(email) {
        const { data, error } = await supabaseClient.auth.resetPasswordForEmail(email, {
            redirectTo: `${window.location.origin}/pages/reset-password.html`
        });
        if (error) throw error;
        return data;
    },

    async updatePassword(newPassword) {
        const { data, error } = await supabaseClient.auth.updateUser({
            password: newPassword
        });
        if (error) throw error;
        return data;
    },

    onAuthStateChange(callback) {
        return supabaseClient.auth.onAuthStateChange(callback);
    }
};

/**
 * Utility Functions
 */
const Utils = {
    formatPrice(price, currency = STORE_CONFIG.currencySymbol) {
        return `${Number(price).toLocaleString('en-EG')} ${currency}`;
    },

    formatDate(date, locale = 'en-EG') {
        return new Date(date).toLocaleDateString(locale, {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    },

    getAvailableStock(color) {
        return (color.quantity || 0) - (color.reserved_quantity || 0);
    },

    getPrimaryImage(images) {
        if (!images || images.length === 0) return '/assets/images/placeholder.jpg';
        const primary = images.find(img => img.is_primary);
        return primary ? primary.image_url : images[0].image_url;
    },

    calculateDiscount(original, sale) {
        return Math.round(((original - sale) / original) * 100);
    },

    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    showToast(message, type = 'info') {
        const container = document.getElementById('toast-container') || (() => {
            const div = document.createElement('div');
            div.id = 'toast-container';
            div.className = 'toast-container';
            document.body.appendChild(div);
            return div;
        })();

        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.innerHTML = `
            <span>${message}</span>
            <button onclick="this.parentElement.remove()" style="background:none;border:none;color:var(--color-text-muted);cursor:pointer;">×</button>
        `;
        container.appendChild(toast);

        setTimeout(() => toast.remove(), 5000);
    }
};

// Export for use in other modules
window.supabaseClient = supabaseClient;
window.API = API;
window.Auth = Auth;
window.Utils = Utils;
window.STORE_CONFIG = STORE_CONFIG;
