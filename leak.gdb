#***************************************************#
# Autore: Renata Januškeviča
# 29.05.2014
# Lai palaistu skriptu, ir nepieciešams:
# 1) ielādēt skriptu gdb atkļūdotājā ar "source <script.gdb>" komandu,
# 2) izsaukt lietotāja definēto komandu analyze ar 1 argumentu,
# $arg0: galvenās arēnas adrese, kuru iespējams iegūt ar komandas "p &main_arena" palīdzību;
# Pirms sāks skripta izpildi ir nepieciešams novietot atmiņas izmeti darbā mapē un jāpaliecinās, ka atmiņas izmetes nosaukums ir core
# Piemēram: "analyze 0x845e000"
#***************************************************#

# $arg0: galvenās arēnas adrese
# komanda apstaiga kaudzi, saskaita gabalu skaitu bez norādēm un  izdruka rezultātu
define get_alloc_chunk
	# mainīgie, kas palīdz iegūt norādi uz kaudzi
	set $system_mem = (long *) ($arg0 + 1096)
	set $top_size_address = (long *) ($top_address[0] + 4)
	set $top_chunk_size = $top_size_address[0] & ~7
	set $heap_pointer =  (long *) ($top_address[0] - $system_mem[0] + $top_chunk_size)
	# $malloc_pointer ir norāde, kura tiek atgriezta programmai
	set $malloc_pointer = 0
 	# $unref skaitītājs atmiņas gabaliem bez norādēm
	set $unref = 0

	while ($heap_pointer != $top_address[0])
		# nākamā atmiņas gabalā atrodas kontroles zīmes, p zīme palīdz noteikt vai iepriekšējais gabals tiek iedalīts programmai
		set $next_chunk =  $heap_pointer + (($heap_pointer[1] & ~7)/4)
		# $x mainīgajā tiek saglabāta atrasta simbolu virkne no datnes ar heksadecimālo saturu
		set $x = 0
		if (($next_chunk[1] & 1) == 1)
			set $malloc_pointer = $heap_pointer + 2

			# tiek meklēta norāde
			eval "shell cat gdb.core | grep %x > gdb.log", $malloc_pointer
			shell echo set \$x=\"$(cat gdb.log)\" > gdb.log
			# tiek nolasīta $x vērtība "
			source gdb.log
			
			if (sizeof($x) == 1) 
				set $unref = $unref + 1
				printf "Nav atrasta norāde uz adresi: %x\n", $malloc_pointer
			end
		end
		# kārtējais gabals ir apstrādāts, ir nepieciešams pārvietot kaudzes norādi
		set $heap_pointer =  $heap_pointer + (($heap_pointer[1] & ~7)/4)
	end
	shell rm gdb.log
	shell rm gdb.core
	printf "Ir pazaudēti: %i gabali.\n", $unref	
end

# $arg0: galvenās arēnas adrese
# komanda saglabā atmiņas izmeti heksadecimālajā formātā un izdzēš atstarpes, jo dati var netikt izlīdzināti
define analyze
	set $top_address = (long *) ($arg0 + 48)

	if ($top_address[0] != 0)
		shell od -t x core > gdb_tmp.core
		shell cat gdb_tmp.core | tr -d ' ' > gdb.core
		shell rm gdb_tmp.core
		printf "\n------------- Atmiņas noplūde --------\n"
		get_alloc_chunk $arg0
	else
		printf "Atmiņa programmā netiek dinamiski iedalīta."
	end
end