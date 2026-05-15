<?php

namespace App\Http\Controllers\Api\Friend;

use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;
use App\Http\Resources\FindUserCollection;

class FindFriendController extends Controller
{
    use ApiResponse;

    // find contact user
    // public function findContacts(Request $request)
    // {
    //     $user = auth('api')->user();

    //     $validated = $request->validate([
    //         'contacts' => 'required|array|min:1',
    //         'contacts.*' => 'string',
    //         'search' => 'nullable|string',
    //     ]);

    //     // Normalize numbers
    //     $contacts = collect($validated['contacts'])->map(function ($number) {
    //         // Remove all characters except digits and "+"
    //         $number = preg_replace('/[^0-9\+]/', '', $number);

    //         // If number starts with multiple +, fix it
    //         $number = ltrim($number, '+');
    //         $number = '+' . $number;

    //         return $number;
    //     })->unique()->values();


    //     // Query users who match any contact number
    //     $query = User::whereIn('phone', $contacts)
    //         ->where('id', '!=', $user->id)
    //         ->whereNotIn('id', function ($q) use ($user) {
    //             $q->select('friend_id')
    //                 ->from('friends')
    //                 ->where('user_id', $user->id);
    //         })
    //         ->whereNotIn('id', function ($q) use ($user) {
    //             $q->select('blocked_user_id')
    //                 ->from('blocked_users')
    //                 ->where('user_id', $user->id);
    //         });

    //     // Optional search
    //     if (!empty($validated['search'])) {
    //         $search = $validated['search'];
    //         $query->where(function ($q) use ($search) {
    //             $q->where('username', 'like', "%{$search}%")
    //                 ->orWhere('first_name', 'like', "%{$search}%")
    //                 ->orWhere('last_name', 'like', "%{$search}%")
    //                 ->orWhere('email', 'like', "%{$search}%")
    //                 ->orWhere('phone', 'like', "%{$search}%");
    //         });
    //     }

    //     $users = $query->select('id', 'first_name', 'last_name', 'username', 'email', 'avatar', 'phone')
    //         ->paginate(15);

    //     return $this->success(
    //         new FindUserCollection($users),
    //         'Matching contacts fetched successfully.'
    //     );
    // }



    public function findContacts(Request $request)
    {
        $user = auth('api')->user();

        $validated = $request->validate([
            'contacts' => 'required|array|min:1',
            'contacts.*' => 'string',
        ]);

        // Search keyword from query params
        $search = $request->query('search');

        // Normalize numbers
        $contacts = collect($validated['contacts'])->map(function ($number) {
            // Remove all non-numeric and non-plus characters
            $number = preg_replace('/[^0-9\+]/', '', $number);

            // Fix multiple '+' or malformed numbers
            $number = ltrim($number, '+');
            $number = '+' . $number;

            return $number;
        })->unique()->values();

        // Main query.
        //
        // The blocked-users join is `user_blocks` keyed on `block_user_id`
        // — matching the migration in
        // 2025_10_29_042417_create_user_blocks_table.php and the rest of
        // the codebase (ChatController, V2\SingleChatController). The old
        // `blocked_users` / `blocked_user_id` names never existed and
        // caused this endpoint to throw at the SQL layer.
        $query = User::whereIn('phone', $contacts)
            ->where('id', '!=', $user->id)
            ->whereNotIn('id', function ($q) use ($user) {
                $q->select('block_user_id')
                    ->from('user_blocks')
                    ->where('user_id', $user->id);
            });

        // Optional search filter
        if (!empty($search)) {
            $query->where(function ($q) use ($search) {
                $q->where('username', 'like', "%{$search}%")
                    ->orWhere('first_name', 'like', "%{$search}%")
                    ->orWhere('last_name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        // Select fields + check if already a friend
        $users = $query->select(
            'id',
            'first_name',
            'last_name',
            'username',
            'email',
            'avatar',
            'phone',
            DB::raw("CASE WHEN id IN (
            SELECT friend_id FROM friends WHERE user_id = {$user->id}
        ) THEN true ELSE false END AS is_friend")
        )->paginate(15);

        return $this->success(
            new FindUserCollection($users),
            'Matching contacts fetched successfully.'
        );
    }
}
