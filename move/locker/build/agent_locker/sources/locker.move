module agent_locker::locker {
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    use std::type_name;

    const E_NOT_OWNER:     u64 = 0;
    const E_STILL_LOCKED:  u64 = 1;
    const E_ZERO_AMOUNT:   u64 = 2;
    const E_ZERO_DURATION: u64 = 3;

    public struct LockedToken<phantom T> has key, store {
        id: UID,
        owner:       address,
        unlock_time: u64,
        locked_at:   u64,
        amount:      u64,
        coin:        Coin<T>,
    }

    public struct TokenLocked has copy, drop {
        lock_id:     ID,
        owner:       address,
        coin_type:   std::ascii::String,
        amount:      u64,
        locked_at:   u64,
        unlock_time: u64,
    }

    public struct TokenUnlocked has copy, drop {
        lock_id:     ID,
        owner:       address,
        amount:      u64,
        unlocked_at: u64,
    }

    public entry fun lock<T>(
        coin:        Coin<T>,
        duration_ms: u64,
        clock:       &Clock,
        ctx:         &mut TxContext,
    ) {
        let amount = coin::value(&coin);
        assert!(amount > 0,      E_ZERO_AMOUNT);
        assert!(duration_ms > 0, E_ZERO_DURATION);

        let now         = clock::timestamp_ms(clock);
        let unlock_time = now + duration_ms;
        let owner       = ctx.sender();

        let lock_obj = LockedToken<T> {
            id:          object::new(ctx),
            owner,
            unlock_time,
            locked_at:   now,
            amount,
            coin,
        };

        event::emit(TokenLocked {
            lock_id:     object::id(&lock_obj),
            owner,
            coin_type:   type_name::get<T>().into_string(),
            amount,
            locked_at:   now,
            unlock_time,
        });

        transfer::transfer(lock_obj, owner);
    }

    public entry fun unlock<T>(
        lock_obj: LockedToken<T>,
        clock:    &Clock,
        ctx:      &mut TxContext,
    ) {
        let LockedToken { id, owner, unlock_time, locked_at: _, amount, coin } = lock_obj;
        assert!(ctx.sender() == owner,                     E_NOT_OWNER);
        assert!(clock::timestamp_ms(clock) >= unlock_time, E_STILL_LOCKED);

        event::emit(TokenUnlocked {
            lock_id:     id.to_inner(),
            owner,
            amount,
            unlocked_at: clock::timestamp_ms(clock),
        });

        id.delete();
        transfer::public_transfer(coin, owner);
    }

    public fun lock_info<T>(lock_obj: &LockedToken<T>): (address, u64, u64, u64) {
        (lock_obj.owner, lock_obj.unlock_time, lock_obj.locked_at, lock_obj.amount)
    }

    public fun is_unlockable<T>(lock_obj: &LockedToken<T>, clock: &Clock): bool {
        clock::timestamp_ms(clock) >= lock_obj.unlock_time
    }
}