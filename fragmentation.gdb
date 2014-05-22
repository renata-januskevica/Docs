define free_chunk_list
	# adress where bin starts
	set $start = (long *) ($arg0 + 56 + $arg1*8)

	# malloc returned to programm
	set $free_chunk = (long *) ($start[1] + 8)
	set $chunk_count = 0
	set $chunk_max_size = 0
	set $total_size = 0
	
	while ($free_chunk != $start)
		set $chunk_size = ($free_chunk[-1] & ~7) - 8 
		printf "chunk adress: %x  size:%-8i fd:0x%x bk:0x%x \n", $free_chunk, $chunk_size, $free_chunk[0], $free_chunk[1]

		if ($chunk_count == 0)
			set $chunk_max_size = $chunk_size 
			set $chunk_min_size = $chunk_size
		else
			if ($chunk_min_size > $chunk_size)
				set $chunk_min_size = $chunk_size
			end
			if ($chunk_max_size < $chunk_size)
				set $chunk_max_size = $chunk_size
			end
		end
		set $chunk_count = $chunk_count + 1
		set $total_size = $total_size + $chunk_size
		set $free_chunk = (long *) ($free_chunk[1] + 8)

	end
	if ($chunk_count == 0)
 		printf "Bin number %i: empty\n", $arg1 + 1
 	else
 		printf "Bin number %i: %i chunks (%i - %i bytes), total = %i bytes\n", $arg1 + 1, $chunk_count, $chunk_min_size,     $chunk_max_size, $total_size
 	end

end

define analyze
	set $free_in_arena = 0
	set $bin_nu = 0
	set $biggest_free_size = 0
	while ($bin_nu < 127)
		free_chunk_list $arg0 $bin_nu
		if ($biggest_free_size < $chunk_max_size)
			set $biggest_free_size = $chunk_max_size
		end
		set $bin_nu = $bin_nu + 1
		set $free_in_arena = $free_in_arena + $total_size	
	end
	printf "Total free in arena 0x%llx: %3i bytes (%i KiB, %i MiB)", $arg0, $free_in_arena, $free_in_arena/1024, $free_in_arena/1024/1024
	printf ", biggest chunk size: %i bytes\n", $biggest_free_size
	set $max_system_mem = *($arg0 + 1100)
	set $top_chunk_size = *(*($arg0 + 48) + 4) - 1
	set $alloc_reached = $max_system_mem - $top_chunk_size
	set $live_memory = $alloc_reached - $free_in_arena
	printf "Memory reached by allocator %i bytes (%i KiB, %i MiB)\n", $alloc_reached, $alloc_reached/1024, $alloc_reached/1024/1024
	printf "Live memory (used by the task) %i bytes (%i KiB, %i MiB)\n", $live_memory, $live_memory/1024, $live_memory/1024/1024
	printf "Fragmentation: %i%%\n", ((double)$alloc_reached/$live_memory - 1)*100
end

