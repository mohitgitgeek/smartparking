package com.smartparking.controller;

import org.springframework.web.bind.annotation.*;
import org.springframework.jdbc.core.JdbcTemplate;
import lombok.RequiredArgsConstructor;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/slots")
@RequiredArgsConstructor
public class SlotController {
    private final JdbcTemplate jdbcTemplate;

    @GetMapping("/overview")
    public List<Map<String,Object>> overview(){
        return jdbcTemplate.queryForList("SELECT * FROM parking.vw_slot_overview ORDER BY zone_name, slot_number");
    }
}
