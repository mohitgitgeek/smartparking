package com.smartparking.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "roles", schema = "parking")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name="role_name", unique = true, nullable = false)
    private String roleName;

    @Column(name="role_description")
    private String roleDescription;
}
