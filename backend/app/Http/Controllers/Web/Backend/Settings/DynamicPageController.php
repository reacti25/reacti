<?php

namespace App\Http\Controllers\Web\Backend\Settings;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\DynamicPageService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Yajra\DataTables\DataTables;

/**
 * Manages CMS-style dynamic content pages (web guard).
 *
 * Two roles in one controller:
 *  - Admin CRUD for `DynamicPage` records via the `admin.dynamic_page.*`
 *    routes in routes/backend.php — the `index` action renders
 *    `backend.layouts.settings.dynamic_page.index` and also serves its
 *    Yajra DataTables AJAX feed, with create/edit views and store/update/
 *    status/destroy actions.
 *  - Read-only JSON endpoints (`privacyPolicy`, `agreement`) that return the
 *    matching active page content, consumed by the mobile app.
 *
 * This is a thin controller: it validates input, builds the Yajra
 * DataTables chain, and shapes the view/redirect/JSON responses. The DB
 * reads and writes live in {@see DynamicPageService}.
 */
class DynamicPageController extends Controller
{

    use ApiResponse;

    /**
     * @param  DynamicPageService  $dynamicPageService  Dynamic-page business logic.
     */
    public function __construct(private readonly DynamicPageService $dynamicPageService)
    {
        parent::__construct();
    }


    /**
     * Return the active "privacy policy" dynamic page as JSON.
     *
     * @return \Illuminate\Http\JsonResponse  Success payload with the page rows, or a 500 error.
     */
    public function privacyPolicy()
    {
        try {

            $data = $this->dynamicPageService->activePagesBySlug('privacy-policy');

            if (!$data) {
                return $this->success([], 'Privacy policy data not found.', 200);
            }

            return $this->success($data, 'Privacy policy data retrieved successfully.', 200);
        } catch (Exception $e) {

            Log::error($e->getMessage());
            return $this->error([], $e->getMessage(), 500);
        }
    }


    /**
     * Return the active "terms and conditions" dynamic page as JSON.
     *
     * @return \Illuminate\Http\JsonResponse  Success payload with the page rows, or a 500 error.
     */
    public function agreement()
    {
        try {

            $data = $this->dynamicPageService->activePagesBySlug('terms-and-condation');

            if (!$data) {
                return $this->success([], 'terms-and-condation data not found.', 200);
            }

            return $this->success($data, 'terms-and-condation data retrieved successfully.', 200);
        } catch (Exception $e) {

            Log::error($e->getMessage());
            return $this->error([], $e->getMessage(), 500);
        }
    }


    /**
     * List dynamic pages, or serve the DataTables AJAX feed.
     *
     * @param  Request  $request  The current request; an AJAX request triggers the DataTables JSON branch.
     * @return \Illuminate\View\View|mixed  The list view, or the DataTables JSON payload for AJAX calls.
     */
    public function index(Request $request)
    {

        // DataTables fetches its rows via AJAX; non-AJAX hits render the page.
        if ($request->ajax()) {
            $data = $this->dynamicPageService->listQuery($request->input('search.value'));
            return DataTables::of($data)
                ->addIndexColumn()
                ->addColumn('page_content', function ($data) {
                    $page_content       = $data->page_content;
                    // Truncate long content to a 100-char preview for the table cell.
                    $short_page_content = strlen($page_content) > 100 ? substr($page_content, 0, 100) . '...' : $page_content;
                    return '<p>' . $short_page_content . '</p>';
                })

                ->addColumn('status', function ($data) {
                    $backgroundColor = $data->status == "active" ? '#4CAF50' : '#ccc';
                    $sliderTranslateX = $data->status == "active" ? '26px' : '2px';
                    $sliderStyles = "position: absolute; top: 2px; left: 2px; width: 20px; height: 20px; background-color: white; border-radius: 50%; transition: transform 0.3s ease; transform: translateX($sliderTranslateX);";

                    $status = '<div class="form-check form-switch" style="margin-left:40px; position: relative; width: 50px; height: 24px; background-color: ' . $backgroundColor . '; border-radius: 12px; transition: background-color 0.3s ease; cursor: pointer;">';
                    $status .= '<input onclick="showStatusChangeAlert(' . $data->id . ')" type="checkbox" class="form-check-input" id="customSwitch' . $data->id . '" getAreaid="' . $data->id . '" name="status" style="position: absolute; width: 100%; height: 100%; opacity: 0; z-index: 2; cursor: pointer;">';
                    $status .= '<span style="' . $sliderStyles . '"></span>';
                    $status .= '<label for="customSwitch' . $data->id . '" class="form-check-label" style="margin-left: 10px;"></label>';
                    $status .= '</div>';

                    return $status;
                })
                ->addColumn('action', function ($data) {
                    return '<div class="btn-group btn-group-sm" role="group" aria-label="Basic example">
                              <a href="' . route('admin.dynamic_page.edit', ['id' => $data->id]) . '" type="button" class="btn btn-primary text-white" title="Edit">
                              <i class="bi bi-pencil"></i>
                              </a>
                              <!---<a href="#" onclick="showDeleteConfirm(' . $data->id . ')" type="button" class="btn btn-danger text-white" title="Delete">
                                    <i class="bi bi-trash"></i>
                                </a> -->
                            </div>';
                })


                // These columns contain HTML and must not be escaped.
                ->rawColumns(['page_content', 'status', 'action'])
                ->make();
        }
        return view('backend.layouts.settings.dynamic_page.index');
    }

    /**
     * Show the create-dynamic-page form.
     *
     * @return \Illuminate\View\View|\Illuminate\Http\RedirectResponse  The create view, or a redirect if the user check fails.
     */
    public function create()
    {
        try {
            // Guard: only resolvable (existing) authenticated users may proceed.
            if (User::find(auth()->user()->id)) {
                return view('backend.layouts.settings.dynamic_page.create');
            }
            return redirect()->route('admin.dynamic_page.index');
        } catch (Exception $e) {
            return redirect()->route('admin.dynamic_page.index')->with('t-error', 'Permission Denied.');
        }
    }

    /**
     * Store a new dynamic page.
     *
     * The page slug is derived automatically from the title.
     *
     * @param  Request  $request  Body: page_title, page_content.
     * @return \Illuminate\Http\RedirectResponse  Redirect to the list with a success/error flash message.
     */
    public function store(Request $request)
    {
        try {
            $validator = Validator::make($request->all(), [
                'page_title'   => 'required|string|max:255',
                'page_content' => 'required|string',
            ]);

            if ($validator->fails()) {
                return redirect()->back()->withErrors($validator)->withInput();
            }

            $this->dynamicPageService->create($request->page_title, $request->page_content);

            return redirect()->route('admin.dynamic_page.index')->with('t-success', 'Dynamic Page Created Successfully.');
        } catch (Exception $e) {
            return redirect()->route('admin.dynamic_page.index')->with('t-error', 'Failed to Create Dynamic Page.');
        }
    }



    /**
     * Show the edit-dynamic-page form.
     *
     * @param  int  $id  URL param: the dynamic page to edit.
     * @return \Illuminate\View\View|\Illuminate\Http\RedirectResponse  The edit view, or a redirect if the user check fails.
     */
    public function edit(int $id)
    {
        try {
            // Guard: only resolvable (existing) authenticated users may proceed.
            if (User::find(auth()->user()->id)) {
                $data = $this->dynamicPageService->find($id);
                return view('backend.layouts.settings.dynamic_page.edit', compact('data'));
            }
            return redirect()->route('admin.dynamic_page.index');
        } catch (Exception $e) {
            return redirect()->route('admin.dynamic_page.index')->with('t-error', 'Permission Denied');
        }
    }


    /**
     * Update an existing dynamic page's content.
     *
     * Only the page content is changed here; title and slug are left intact.
     *
     * @param  Request  $request  Body: page_content.
     * @param  int  $id  URL param: the dynamic page to update.
     * @return \Illuminate\Http\RedirectResponse  Redirect to the list with a success/error flash message.
     */
    public function update(Request $request, int $id)
    {
        try {
            // Guard: only resolvable (existing) authenticated users may proceed.
            if (User::find(auth()->user()->id)) {
                $validator = Validator::make($request->all(), [
                    // 'page_title'   => 'nullable|string',
                    'page_content' => 'nullable|string',
                ]);

                if ($validator->fails()) {
                    return redirect()->back()->withErrors($validator)->withInput();
                }

                $data = $this->dynamicPageService->find($id);
                $this->dynamicPageService->update($data, $request->page_content);

                return redirect()->route('admin.dynamic_page.index')->with('t-success', 'Dynamic Page Updated Successfully.');
            }
        } catch (Exception) {
            return redirect()->route('admin.dynamic_page.index')->with('t-error', 'Dynamic Page failed to update');
        }
        return redirect()->route('admin.dynamic_page.index');
    }


    /**
     * Toggle a dynamic page between published (active) and unpublished.
     *
     * @param  int  $id  URL param: the dynamic page to toggle.
     * @return \Illuminate\Http\JsonResponse  JSON payload reflecting the new published state.
     *
     * @throws \Illuminate\Database\Eloquent\ModelNotFoundException  When no page matches the id.
     */
    public function status(int $id)
    {
        $data = $this->dynamicPageService->toggleStatus($id);
        // 'active' means published; the service flipped the state, so the
        // payload reports unpublished when the new status is 'inactive'.
        if ($data->status == 'inactive') {
            return response()->json([
                'success' => false,
                'message' => 'Unpublished Successfully.',
                'data'    => $data,
            ]);
        } else {
            return response()->json([
                'success' => true,
                'message' => 'Published Successfully.',
                'data'    => $data,
            ]);
        }
    }


    /**
     * Delete a dynamic page.
     *
     * @param  int  $id  URL param: the dynamic page to remove.
     * @return \Illuminate\Http\JsonResponse  JSON success payload.
     */
    public function destroy(int $id)
    {
        $this->dynamicPageService->destroy($id);
        return response()->json([
            't-success' => true,
            'message'   => 'Deleted successfully.',
        ]);
    }
}
