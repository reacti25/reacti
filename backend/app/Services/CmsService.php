<?php

namespace App\Services;

use Exception;

use App\Models\CMS;
use App\Helper\Helper;
use Illuminate\Support\Facades\Log;

/**
 * Encapsulates write operations on CMS content records.
 *
 * Centralises deletion (including cleanup of associated background and
 * image files) and active/inactive status toggling so controllers stay
 * thin. Failures are swallowed and logged rather than surfaced.
 */
class CmsService
{
    /**
     * Delete a CMS record and remove its background and image files from disk.
     *
     * Any exception (e.g. missing record) is logged and suppressed so the
     * caller is not interrupted.
     *
     * @param  int|string  $id  Primary key of the CMS record to delete.
     * @return void
     */
    public function destroy($id)
    {
        try {
            $data = CMS::findOrFail($id);

            if ($data->bg && file_exists(public_path($data->bg))) {
                Helper::fileDelete(public_path($data->bg));
            }

            if ($data->image && file_exists(public_path($data->image))) {
                Helper::fileDelete(public_path($data->image));
            }

            $data->delete();
        } catch (Exception $e) {
            Log::error($e->getMessage());
        }
    }


    /**
     * Toggle a CMS record between the `active` and `inactive` states.
     *
     * Any exception (e.g. missing record) is logged and suppressed.
     *
     * @param  int|string  $id  Primary key of the CMS record to toggle.
     * @return void
     */
    public function status($id)
    {
        try {
            $data = CMS::findOrFail($id);
            $data->status = $data->status === 'active' ? 'inactive' : 'active';
            $data->save();
        } catch (Exception $e) {
            Log::error($e->getMessage());
        }
    }

}
