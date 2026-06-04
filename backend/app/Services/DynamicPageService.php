<?php

namespace App\Services;

use App\Http\Controllers\Web\Backend\Settings\DynamicPageController;
use App\Models\DynamicPage;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Str;

/**
 * Business logic for CMS-style dynamic content pages.
 *
 * Extracted from {@see DynamicPageController}
 * so the controller only validates input, builds the Yajra DataTables
 * chain, and shapes the view/redirect/JSON responses. The service performs
 * the DB reads and writes; it does not build the DataTables payload (that
 * chain stays in the controller per the refactor rules). No behaviour
 * change from the pre-refactor controller.
 */
class DynamicPageService
{
    /**
     * Fetch the active dynamic pages matching a slug.
     *
     * Backs the read-only JSON endpoints (`privacyPolicy`, `agreement`).
     *
     * @param  string  $slug  The `page_slug` to filter on.
     * @return Collection The matching active page rows.
     */
    public function activePagesBySlug(string $slug): Collection
    {
        return DynamicPage::where('page_slug', $slug)->where('status', 'active')->get();
    }

    /**
     * Build the base query for the DataTables listing.
     *
     * Returns a `latest()`-ordered query, optionally narrowed by the
     * DataTables search term against `page_title`. The controller wraps
     * the returned query in the Yajra builder chain.
     *
     * @param  string|null  $searchTerm  The DataTables search box value.
     * @return Builder The base query for `DataTables::of()`.
     */
    public function listQuery(?string $searchTerm): Builder
    {
        $data = DynamicPage::latest();

        // Apply DataTables' built-in search box against the page title.
        if (! empty($searchTerm)) {
            $data->where('page_title', 'LIKE', "%$searchTerm%");
        }

        return $data;
    }

    /**
     * Create a new dynamic page.
     *
     * The page slug is derived automatically from the title and the page
     * is created in the `active` state.
     *
     * @param  string  $pageTitle  The page title.
     * @param  string  $pageContent  The page body content.
     * @return DynamicPage The created page.
     */
    public function create(string $pageTitle, string $pageContent): DynamicPage
    {
        return DynamicPage::create([
            'page_title' => $pageTitle,
            // Slug is generated from the title for clean URL lookups.
            'page_slug' => Str::slug($pageTitle),
            'page_content' => $pageContent,
            'status' => 'active',
        ]);
    }

    /**
     * Find a dynamic page by id.
     *
     * @param  int  $id  The page id.
     * @return DynamicPage|null The page, or null when missing.
     */
    public function find(int $id): ?DynamicPage
    {
        return DynamicPage::find($id);
    }

    /**
     * Update an existing dynamic page's content.
     *
     * Only the page content is changed; title and slug are left intact,
     * exactly as the pre-refactor controller did.
     *
     * @param  DynamicPage  $page  The page to update (already resolved).
     * @param  string|null  $pageContent  The new page content.
     * @return DynamicPage The updated page.
     */
    public function update(DynamicPage $page, ?string $pageContent): DynamicPage
    {
        $page->update([
            // 'page_title'   => $request->page_title,
            // 'page_slug'    => Str::slug($request->page_title),
            'page_content' => $pageContent,
        ]);

        return $page;
    }

    /**
     * Toggle a dynamic page between published (active) and unpublished.
     *
     * Returns the page after the flip; the controller branches on the new
     * status to build the matching JSON payload.
     *
     * @param  int  $id  The page id.
     * @return DynamicPage The page with its status flipped.
     *
     * @throws ModelNotFoundException When no page matches the id.
     */
    public function toggleStatus(int $id): DynamicPage
    {
        $data = DynamicPage::findOrFail($id);

        // 'active' means published; flip to the opposite state on each call.
        if ($data->status == 'active') {
            $data->status = 'inactive';
            $data->save();
        } else {
            $data->status = 'active';
            $data->save();
        }

        return $data;
    }

    /**
     * Delete a dynamic page.
     *
     * @param  int  $id  The page id to remove.
     */
    public function destroy(int $id): void
    {
        $page = DynamicPage::find($id);
        $page->delete();
    }
}
