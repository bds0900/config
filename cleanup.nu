# A Nushell script to recursively find and delete 'bin' and 'obj' directories.
# DEEP FIX 5: Manual Stack-Based Recursion.
# This approach abandons all external commands (find) and globbing.
# It uses a manual 'while' loop and the internal 'ls' command to traverse the tree.
# This avoids all pipeline stream and type mismatch errors observed in Nushell 0.108.

# --- DEBUG: INITIAL EXECUTION CHECK ---
print "(ansi green)--- SCRIPT EXECUTION STARTED (Deep Fix 5: Manual Recursion) --- (ansi reset)"
# -------------------------------------

try {
    # Initialize the stack with the current directory
    mut dirs_to_process = ["."]
    mut dirs_to_delete = []

    print $"(ansi blue)DEBUG: Starting manual directory traversal from root '.'(ansi reset)"

    # Loop until there are no more directories to inspect
    # FIX: Replaced '($dirs_to_process | is-empty) == $false' with length check
    # to avoid 'Variable not found' error for $false in older Nushell versions.
    while ($dirs_to_process | length) > 0 {
        # 1. POP: Get the first directory from the queue (Breadth-First Search style)
        let current_dir = ($dirs_to_process | first)
        
        # Remove the first item from the mutable list (Queue behavior)
        # We use 'skip 1' to drop the first item.
        $dirs_to_process = ($dirs_to_process | skip 1)

        # 2. INSPECT: List contents of the current directory
        # We use a try block because 'ls' might fail on permission denied folders
        try {
            # Capture ls output to a variable to avoid pipeline instability
            let items = (ls $current_dir)

            # Manually iterate through items to avoid 'where' pipeline errors
            for item in $items {
                # SAFE TYPE CHECK: Use string interpolation to safely get the type and name
                # This prevents the 'Type mismatch' errors we saw earlier.
                let item_type = $"($item.type)"
                let item_name = $"($item.name)"

                # We only care about directories
                if $item_type == "dir" {
                    # CHECK MATCH: Does the folder name end with bin or obj?
                    # Regex: [/\\] means slash or backslash. (bin|obj)$ means ending with bin or obj.
                    if ($item_name =~ "[/\\\\](bin|obj)$") or ($item_name =~ "^(bin|obj)$") {
                        # FOUND ONE! Add to delete list.
                        # We do NOT add it to 'dirs_to_process' because we are deleting it,
                        # so no need to search inside it.
                        $dirs_to_delete = ($dirs_to_delete | append $item_name)
                    } else {
                        # NOT A MATCH: Add to queue to search inside it later.
                        $dirs_to_process = ($dirs_to_process | append $item_name)
                    }
                }
            }
        } catch {
            # Just ignore folders we can't read
        }
    }

    # 3. REPORT & DELETE
    if ($dirs_to_delete | is-empty) {
        print "✅ No 'bin' or 'obj' directories found for cleanup."
    } else {
        print $"Found (ansi yellow)($dirs_to_delete | length)(ansi reset) directories to delete:"
        
        # Display paths
        for path in $dirs_to_delete {
            print $"  -> (ansi red)($path)(ansi reset)"
        }
        
        print ""
        print "Starting recursive deletion (rm -r)..."

        # Delete loop
        for path in $dirs_to_delete {
            try {
                # Final existence check using string interpolation for safety
                let check_path = $"($path)"
                
                # We simply try to delete. If it's gone, we catch the error.
                rm -r $check_path
                
                # FIX: Wrapped $check_path in parentheses ($check_path) to ensure correct interpolation
                print $"  (ansi green)Deleted: ($check_path)(ansi reset)"
            } catch { |err|
                # FIX: Wrapped error variables in parentheses too
                print $"  (ansi red)Failed to delete: ($path) (Error: ($err.msg))(ansi reset)"
            }
        }
    }

} catch { |err|
    print ""
    print "(ansi red)(ansi bold)!!! FATAL SCRIPT ERROR !!!(ansi reset)"
    print $"Error Message: (ansi red)($err.msg)(ansi reset)"
    print "This error occurred during the manual recursion logic."
    print ""
}

print ""
print "Cleanup process complete."
