def merge($a; $b):
  if ($a | type) == "object" and ($b | type) == "object" then
    reduce (($a + $b) | keys_unsorted[]) as $k ({};
      .[$k] =
        if ($a | has($k)) then
          if ($a[$k] | type) == "array" and ($b[$k] | type) == "array" then
            $a[$k] + $b[$k] | unique
          else
            merge($a[$k]; $b[$k])
          end
        else
          $b[$k]
        end
    )
  else
    $a
  end;

merge(.; input)

