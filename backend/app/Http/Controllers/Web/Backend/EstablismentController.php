<?php

namespace App\Http\Controllers\Web\Backend;

use App\Http\Controllers\Controller;
use App\Models\Establishment;
use Exception;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Yajra\DataTables\Facades\DataTables;

/**
 * Admin CRUD for `Establishment` records (web guard).
 *
 * Backs the `admin.establishment.*` routes in routes/backend.php. The
 * `index` action renders the `backend.layouts.establishment.index` Blade
 * view and also answers the page's Yajra DataTables AJAX request; the
 * remaining actions create, edit, update, delete, and toggle the status of
 * establishments, returning redirects or JSON.
 */
class EstablismentController extends Controller
{
    /**
     * List establishments, or serve the DataTables AJAX feed.
     *
     * @param  Request  $request  The current request; an AJAX request triggers the DataTables JSON branch.
     * @return View|mixed The list view, or the DataTables JSON payload for AJAX calls.
     */
    public function index(Request $request)
    {
        // DataTables fetches its rows via AJAX; non-AJAX hits render the page.
        if ($request->ajax()) {
            $data = Establishment::all();

            return DataTables::of($data)
                ->addIndexColumn()
                ->addColumn('status', function ($data) {
                    $backgroundColor = $data->status == 'active' ? '#4CAF50' : '#ccc';
                    $sliderTranslateX = $data->status == 'active' ? '26px' : '2px';
                    $sliderStyles = "position: absolute; top: 2px; left: 2px; width: 20px; height: 20px; background-color: white; border-radius: 50%; transition: transform 0.3s ease; transform: translateX($sliderTranslateX);";

                    $status = '<div class="form-check form-switch" style="margin-left:40px; position: relative; width: 50px; height: 24px; background-color: '.$backgroundColor.'; border-radius: 12px; transition: background-color 0.3s ease; cursor: pointer;">';
                    $status .= '<input onclick="showStatusChangeAlert('.$data->id.')" type="checkbox" class="form-check-input" id="customSwitch'.$data->id.'" getAreaid="'.$data->id.'" name="status" style="position: absolute; width: 100%; height: 100%; opacity: 0; z-index: 2; cursor: pointer;">';
                    $status .= '<span style="'.$sliderStyles.'"></span>';
                    $status .= '<label for="customSwitch'.$data->id.'" class="form-check-label" style="margin-left: 10px;"></label>';
                    $status .= '</div>';

                    return $status;
                })
                ->addColumn('action', function ($data) {
                    return '<div class="btn-group btn-group-sm" role="group" aria-label="Basic example">
                                <a href="#" type="button" onclick="goToEdit('.$data->id.')" class="btn btn-primary fs-14 text-white delete-icn" title="Edit">
                                    <i class="fe fe-edit"></i>
                                </a>
                                <a href="#" type="button" onclick="showDeleteConfirm('.$data->id.')" class="btn btn-danger fs-14 text-white delete-icn" title="Delete">
                                    <i class="fe fe-trash"></i>
                                </a>
                            </div>';
                })
                // status/action contain HTML and must not be escaped.
                ->rawColumns(['status', 'action'])
                ->make();
        }

        return view('backend.layouts.establishment.index');
    }

    /**
     * Store a new establishment.
     *
     * @param  Request  $request  Body: title (required, unique among establishments).
     * @return RedirectResponse Redirect back to the establishment list with a flash message.
     */
    public function store(Request $request)
    {
        // Title must be unique so the same establishment is not added twice.
        $validate = $request->validate([
            'title' => 'required|unique:establishments,title',
        ]);

        try {
            Establishment::create($validate);
            session()->put('t-success', 'Establishment created successfully');
        } catch (Exception $e) {
            session()->put('t-error', $e->getMessage());
        }

        return redirect()->route('admin.establishment.index')->with('success', 'Establishment created successfully');
    }

    /**
     * Fetch a single establishment for the edit form.
     *
     * @param  Establishment  $establishment  Route-model placeholder (the lookup uses $id instead).
     * @param  int|string  $id  URL param: the establishment to load.
     * @return JsonResponse JSON establishment payload, or a 404 error.
     */
    public function edit(Establishment $establishment, $id)
    {
        $establishment = Establishment::find($id);

        if (! $establishment) {
            return response()->json([
                'success' => false,
                'message' => 'Establishment not found.',
            ], 404);
        }

        return response()->json($establishment);
    }

    /**
     * Update an existing establishment.
     *
     * @param  Request  $request  Body: title (required).
     * @param  int|string  $id  URL param: the establishment to update.
     * @return RedirectResponse Redirect back to the establishment list.
     */
    public function update(Request $request, $id)
    {
        $validate = $request->validate([
            'title' => 'required',
        ]);

        try {
            $establishment = Establishment::findOrFail($id);
            $establishment->update($validate);
            session()->put('t-success', 'Establishment updated successfully');
        } catch (Exception $e) {
            session()->put('t-error', $e->getMessage());
        }

        return redirect()->route('admin.establishment.index');
    }

    /**
     * Delete an establishment.
     *
     * @param  string  $id  URL param: the establishment to remove.
     * @return JsonResponse JSON success payload, or a 404 error.
     *
     * @throws ModelNotFoundException When no establishment matches the id.
     */
    public function destroy(string $id)
    {
        $data = Establishment::findOrFail($id);
        if (empty($data)) {
            return response()->json([
                'success' => false,
                'message' => 'Establishment not found.',
            ], 404);
        }

        $data->delete();

        return response()->json([
            'success' => true,
            'message' => 'Establishment deleted successfully!',
        ], 200);
    }

    /**
     * Toggle an establishment's active/inactive status.
     *
     * Driven by the status switch in the DataTables row.
     *
     * @param  int  $id  URL param: the establishment whose status is toggled.
     * @return JsonResponse JSON success/error payload.
     */
    public function status(int $id): JsonResponse
    {
        $data = Establishment::find($id);

        if (! $data) {
            return response()->json([
                'status' => 'error',
                'message' => 'Establishment not found.',
            ]);
        }
        // Flip between the two states on each toggle.
        $data->status = $data->status === 'active' ? 'inactive' : 'active';
        $data->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Status Changed successfully!',
        ]);
    }
}
