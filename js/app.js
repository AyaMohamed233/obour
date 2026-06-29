/**
 * BAGS STORE - Main Application JavaScript
 * ==========================================
 * Core functionality for the store frontend
 */

// DOM Ready
document.addEventListener('DOMContentLoaded', () => {
    initApp();
});

/**
 * Initialize Application
 */
async function initApp() {
    // Setup auth state listener
    Auth.onAuthStateChange((event, session) => {
        updateAuthUI(session?.user);
        updateCartCount();
        updateWishlistCount();
    });

    // Initial auth check
    const user = await Auth.getUser();
    updateAuthUI(user);

    // Load page-specific content
    loadPageContent();

    // Setup event listeners
    setupEventListeners();

    // Update cart and wishlist counts
    updateCartCount();
    updateWishlistCount();
}

/**
 * Update Authentication UI
 */
function updateAuthUI(user) {
    const accountIcon = document.getElementById('account-icon');
    if (accountIcon) {
        if (user) {
            accountIcon.href = 'pages/account.html';
            accountIcon.innerHTML = '<i class="fas fa-user"></i>';
        } else {
            accountIcon.href = 'pages/login.html';
            accountIcon.innerHTML = '<i class="far fa-user"></i>';
        }
    }
}

/**
 * Update Cart Count Badge
 */
async function updateCartCount() {
    try {
        const cart = await API.getCart();
        const count = cart.reduce((sum, item) => sum + item.quantity, 0);
        const badge = document.getElementById('cart-count');
        if (badge) {
            badge.textContent = count;
            badge.classList.toggle('hidden', count === 0);
        }
    } catch (error) {
        console.log('Cart count update skipped:', error.message);
    }
}

/**
 * Update Wishlist Count Badge
 */
async function updateWishlistCount() {
    try {
        const wishlist = await API.getWishlist();
        const count = wishlist.length;
        const badge = document.getElementById('wishlist-count');
        if (badge) {
            badge.textContent = count;
            badge.classList.toggle('hidden', count === 0);
        }
    } catch (error) {
        console.log('Wishlist count update skipped:', error.message);
    }
}

/**
 * Load Page Content Based on Current Page
 */
function loadPageContent() {
    const path = window.location.pathname;

    if (path.endsWith('index.html') || path.endsWith('/') || path === '') {
        loadHomePage();
    }
}

/**
 * Load Home Page Content
 */
async function loadHomePage() {
    // Load categories
    loadCategories();

    // Load featured products
    loadFeaturedProducts();

    // Load sale products
    loadSaleProducts();

    // Load hero banner
    loadHeroBanner();
}

/**
 * Load Categories
 */
async function loadCategories() {
    const grid = document.getElementById('categories-grid');
    if (!grid) return;

    try {
        const categories = await API.getCategories();

        const categoryImages = {
            'Tote Bags': 'tote_bag_category.png',
            'Handbags': 'handbag_category.png',
            'Crossbody Bags': 'https://images.unsplash.com/photo-1591561954555-607968c989ab?w=400',
            'Backpacks': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
            'Clutches': 'https://images.unsplash.com/photo-1566150905458-1bf1fc113f0d?w=400',
            'Shoulder Bags': 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400'
        };

        grid.innerHTML = categories.slice(0, 5).map(cat => {
            const defaultImage = 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=400';
            const imageSrc = cat.image_url || categoryImages[cat.name] || defaultImage;
            
            return `
            <a href="pages/products.html?category=${cat.slug}" class="category-card">
                <img src="${imageSrc}" alt="${cat.name}">
                <div class="category-card-overlay">
                    <div>
                        <div class="category-card-title">${cat.name}</div>
                        <div class="category-card-count">${cat.product_count || 0} Products</div>
                    </div>
                </div>
            </a>
            `;
        }).join('');
    } catch (error) {
        console.error('Failed to load categories:', error);
        grid.innerHTML = '<p class="text-center text-muted">Failed to load categories</p>';
    }
}

/**
 * Load Featured Products
 */
async function loadFeaturedProducts() {
    const grid = document.getElementById('featured-products');
    if (!grid) return;

    try {
        const products = await API.getProducts({ featured: true, limit: 4 });
        renderProductGrid(grid, products);
    } catch (error) {
        console.error('Failed to load featured products:', error);
        grid.innerHTML = '<p class="text-center text-muted">Failed to load products</p>';
    }
}

/**
 * Load Sale Products
 */
async function loadSaleProducts() {
    const grid = document.getElementById('sale-products');
    if (!grid) return;

    try {
        const sales = await API.getSaleProducts(4);
        const products = sales.map(sale => ({
            ...sale.product,
            sale_price: sale.sale_price || (sale.original_price * (1 - sale.sale_percentage / 100)),
            sale_percentage: sale.sale_percentage
        }));
        renderProductGrid(grid, products, true);
    } catch (error) {
        console.error('Failed to load sale products:', error);
        grid.innerHTML = '<p class="text-center text-muted">Failed to load sale products</p>';
    }
}

/**
 * Load Hero Banner
 */
async function loadHeroBanner() {
    try {
        const banners = await API.getBanners('hero');
        if (banners && banners.length > 0) {
            const banner = banners[0];
            const heroImage = document.getElementById('hero-image');
            if (heroImage && banner.image_url) {
                heroImage.src = banner.image_url;
            }
        }
    } catch (error) {
        console.log('Banner load skipped:', error.message);
    }
}

/**
 * Render Product Grid
 */
function renderProductGrid(container, products, showSaleBadge = false) {
    if (!products || products.length === 0) {
        container.innerHTML = '<p class="text-center text-muted" style="grid-column: 1/-1;">No products found</p>';
        return;
    }

    container.innerHTML = products.map(product => createProductCard(product, showSaleBadge)).join('');
}

/**
 * Create Product Card HTML
 */
function createProductCard(product, showSaleBadge = false) {
    const primaryImage = Utils.getPrimaryImage(product.images);
    const hasStock = product.colors?.some(c => Utils.getAvailableStock(c) > 0) ?? true;
    const salePrice = product.sale_price;
    const discount = salePrice ? Utils.calculateDiscount(product.price, salePrice) : 0;

    return `
        <article class="product-card" data-product-id="${product.id}">
            <div class="product-card-image">
                <a href="pages/product.html?slug=${product.slug}">
                    <img src="${primaryImage}" alt="${product.name}" loading="lazy">
                </a>
                ${showSaleBadge && discount > 0 ? `<span class="product-card-badge sale">-${discount}%</span>` : ''}
                ${product.is_new_arrival ? `<span class="product-card-badge new">New</span>` : ''}
                ${!hasStock ? `<span class="product-card-badge" style="background: var(--color-surface);">Out of Stock</span>` : ''}
                
                <div class="product-card-actions">
                    <button class="btn btn-primary btn-sm" onclick="quickAddToCart('${product.id}')" ${!hasStock ? 'disabled' : ''}>
                        <i class="fas fa-shopping-bag"></i> Add to Cart
                    </button>
                    <button class="btn btn-ghost btn-icon btn-sm" onclick="toggleWishlist('${product.id}')">
                        <i class="far fa-heart"></i>
                    </button>
                </div>
            </div>
            <div class="product-card-content">
                ${product.brand ? `<div class="product-card-brand">${product.brand.name}</div>` : ''}
                <h3 class="product-card-title">
                    <a href="pages/product.html?slug=${product.slug}">${product.name}</a>
                </h3>
                <div class="product-card-price">
                    <span class="current">${Utils.formatPrice(salePrice || product.price)}</span>
                    ${salePrice ? `<span class="original">${Utils.formatPrice(product.price)}</span>` : ''}
                </div>
            </div>
        </article>
    `;
}

/**
 * Quick Add to Cart (first available color)
 */
async function quickAddToCart(productId) {
    try {
        const user = await Auth.getUser();
        if (!user) {
            Utils.showToast('Please login to add items to cart', 'error');
            window.location.href = 'pages/login.html';
            return;
        }

        // Get product details to find first available color
        const products = await API.getProducts();
        const product = products.find(p => p.id === productId);

        if (!product || !product.colors) {
            Utils.showToast('Product not available', 'error');
            return;
        }

        const availableColor = product.colors.find(c => Utils.getAvailableStock(c) > 0);
        if (!availableColor) {
            Utils.showToast('Product is out of stock', 'error');
            return;
        }

        await API.addToCart(productId, availableColor.id, 1);
        Utils.showToast('Added to cart!', 'success');
        updateCartCount();
    } catch (error) {
        Utils.showToast(error.message || 'Failed to add to cart', 'error');
    }
}

/**
 * Toggle Wishlist
 */
async function toggleWishlist(productId) {
    try {
        const user = await Auth.getUser();
        if (!user) {
            Utils.showToast('Please login to manage wishlist', 'error');
            window.location.href = 'pages/login.html';
            return;
        }

        // Check if already in wishlist
        const wishlist = await API.getWishlist();
        const isInWishlist = wishlist.some(item => item.product_id === productId);

        if (isInWishlist) {
            await API.removeFromWishlist(productId);
            Utils.showToast('Removed from wishlist', 'info');
        } else {
            await API.addToWishlist(productId);
            Utils.showToast('Added to wishlist!', 'success');
        }

        updateWishlistCount();
    } catch (error) {
        Utils.showToast(error.message || 'Failed to update wishlist', 'error');
    }
}

/**
 * Setup Event Listeners
 */
function setupEventListeners() {
    // Newsletter form
    const newsletterForm = document.getElementById('newsletter-form');
    if (newsletterForm) {
        newsletterForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = e.target.querySelector('input[type="email"]').value;

            try {
                await API.subscribeNewsletter(email);
                Utils.showToast('Successfully subscribed!', 'success');
                e.target.reset();
            } catch (error) {
                Utils.showToast('Failed to subscribe. Please try again.', 'error');
            }
        });
    }

    // Navbar scroll effect
    let lastScroll = 0;
    window.addEventListener('scroll', () => {
        const navbar = document.getElementById('navbar');
        if (!navbar) return;

        const currentScroll = window.pageYOffset;

        if (currentScroll <= 0) {
            navbar.style.boxShadow = 'none';
        } else {
            navbar.style.boxShadow = 'var(--shadow-lg)';
        }

        lastScroll = currentScroll;
    });

    // Mobile menu toggle
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    if (mobileMenuBtn) {
        mobileMenuBtn.addEventListener('click', () => {
            const nav = document.querySelector('.navbar-nav');
            if (nav) {
                nav.classList.toggle('mobile-open');
            }
        });
    }
}

// Make functions globally available
window.quickAddToCart = quickAddToCart;
window.toggleWishlist = toggleWishlist;
