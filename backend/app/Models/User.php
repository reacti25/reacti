<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Tymon\JWTAuth\Contracts\JWTSubject;

/**
 * Eloquent model for an application user account.
 *
 * Backs the `users` table and is the central identity of the system —
 * the sender/receiver of chats, member of groups, owner of friendships,
 * device tokens and reports. Implements {@see JWTSubject} so accounts
 * can authenticate via JWT on the API guard.
 */
class User extends Authenticatable implements JWTSubject
{
    use HasFactory, Notifiable;

    /**
     * Return the identifier stored in the JWT `sub` claim.
     *
     * @return mixed The user's primary key.
     */
    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    /**
     * Return extra claims to embed in the JWT payload.
     *
     * @return array Empty — no custom claims are added.
     */
    public function getJWTCustomClaims()
    {
        return [];
    }

    /** Attributes mass-assignable when registering or updating a user. */
    protected $fillable = [
        'first_name',
        'last_name',
        'username',
        'email',
        'phone',
        'date_of_birth',
        'password',
        'avatar',
        'cover',
        'bio',
        'address',
        'otp',
        'otp_expires_at',
        'otp_verified_at',
        'reset_password_token',
        'reset_password_token_expire_at',
        'last_activity_at',
        'status',
        'is_google_signin',
        'google_id',
        'is_apple_signin',
        'apple_id',
        'analytics_opt_out',
        'read_receipts',
    ];

    /**
     * Attribute cast definitions.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'date_of_birth' => 'date',
        'last_activity_at' => 'datetime',
        'otp_expires_at' => 'datetime',
        'otp_verified_at' => 'datetime',
        'reset_password_token_expire_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'analytics_opt_out' => 'boolean',
        'read_receipts' => 'boolean',
    ];

    /** Sensitive attributes hidden from array/JSON serialization. */
    protected $hidden = [
        'password',
        'remember_token',
        // Nobody else's business: a birthdate is PII and no screen shows it.
        // UserResource is an allowlist so it can't leak there either — this
        // guards the paths that serialize a User model directly.
        'date_of_birth',
        'created_at',
        'updated_at',
        'otp',
        'reset_password_token',
    ];

    /**
     * Accessor normalising the `avatar` attribute into a usable URL.
     *
     * A value already stored as an absolute URL (e.g. a social-login
     * avatar) is returned untouched; a relative path is expanded to a
     * full URL only for API requests so the mobile app gets a complete
     * link.
     *
     * @param  string|null  $value  Raw stored avatar path or URL.
     * @return string|null A resolvable avatar URL or the raw value.
     */
    public function getAvatarAttribute($value)
    {
        if (filter_var($value, FILTER_VALIDATE_URL)) {
            return $value;
        }
        if (request()->is('api/*') && ! empty($value)) {
            return url($value);
        }

        return $value;
    }

    /**
     * Accessor capitalising the user's first name for display.
     *
     * @param  string|null  $value  Raw stored first name.
     * @return string The first name with its initial letter upper-cased.
     */
    public function getFirstNameAttribute($value): string
    {
        return ucfirst($value ?? '');
    }

    /**
     * Relationship: friend requests this user has sent to others.
     *
     * @return HasMany
     */
    public function sentRequests()
    {
        return $this->hasMany(FriendRequest::class, 'sender_id');
    }

    /**
     * Relationship: friend requests other users have sent to this user.
     *
     * @return HasMany
     */
    public function receivedRequests()
    {
        return $this->hasMany(FriendRequest::class, 'receiver_id');
    }

    /**
     * Relationship: the user's friends in both directions.
     *
     * Friendships are stored as single directed rows, so this unions a
     * query for rows where the user is `user_id` with one where the user
     * is `friend_id`, yielding the complete mutual friend list.
     *
     * @return BelongsToMany
     */
    public function friends()
    {
        // where user_id is me
        $friends1 = $this->belongsToMany(
            User::class,
            'friends',
            'user_id',
            'friend_id'
        )->withTimestamps()->withPivot('became_friends_at');

        // Where friend_id is me
        $friends2 = $this->belongsToMany(
            User::class,
            'friends',
            'friend_id',
            'user_id'
        )->withTimestamps()->withPivot('became_friends_at');

        // When do Union then the same columns specify
        return $friends1->union($friends2->getQuery());
    }

    /**
     * Relationship: users who added this user as their friend
     * (the inverse `friend_id` -> `user_id` direction only).
     *
     * @return BelongsToMany
     */
    public function friendOf()
    {
        return $this->belongsToMany(User::class, 'friends', 'friend_id', 'user_id')
            ->withTimestamps();
    }

    /**
     * Relationship: 1:1 chat messages this user has sent.
     *
     * @return HasMany
     */
    public function senders()
    {
        return $this->hasMany(Chat::class, 'sender_id');
    }

    /**
     * Relationship: 1:1 chat messages this user has received.
     *
     * @return HasMany
     */
    public function receivers()
    {
        return $this->hasMany(Chat::class, 'receiver_id');
    }

    /**
     * Relationship: rooms where this user occupies the `user_one_id` slot.
     *
     * @return HasMany
     */
    public function roomsAsUserOne()
    {
        return $this->hasMany(Room::class, 'user_one_id');
    }

    /**
     * Relationship: rooms where this user occupies the `user_two_id` slot.
     *
     * @return HasMany
     */
    public function roomsAsUserTwo()
    {
        return $this->hasMany(Room::class, 'user_two_id');
    }

    /**
     * Build a query for every `Room` this user participates in,
     * on either side of the conversation.
     *
     * Returns a query builder rather than an Eloquent relation so callers
     * can keep chaining constraints.
     *
     * @return Builder
     */
    public function allRooms()
    {
        return Room::where('user_one_id', $this->id)->orWhere('user_two_id', $this->id);
    }

    /**
     * Relationship: this user's group membership rows.
     *
     * @return HasMany
     */
    public function groupMemberships()
    {
        return $this->hasMany(GroupMember::class, 'user_id');
    }

    /**
     * Relationship: the groups this user belongs to, with the pivot
     * role and join timestamp exposed.
     *
     * @return BelongsToMany
     */
    public function groups()
    {
        return $this->belongsToMany(Group::class, 'group_members', 'user_id', 'group_id')
            ->withPivot('role', 'joined_at')
            ->withTimestamps();
    }

    /**
     * Relationship: the groups this user created and owns.
     *
     * @return HasMany
     */
    public function createdGroups()
    {
        return $this->hasMany(Group::class, 'created_by');
    }

    /**
     * Relationship: group messages this user has sent.
     *
     * @return HasMany
     */
    public function groupMessages()
    {
        return $this->hasMany(GroupMessage::class, 'sender_id');
    }

    /**
     * Relationship: this user's registered Firebase device tokens,
     * used to deliver push notifications.
     *
     * @return HasMany
     */
    public function firebaseTokens()
    {
        return $this->hasMany(FirebaseTokens::class);
    }
}
